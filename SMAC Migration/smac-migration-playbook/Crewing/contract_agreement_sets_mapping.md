# Table Mapping: contract_agreement_sets → contract_agreement_sets

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: contract_agreement_sets
- **Source Script**: `04-migration-scripts/crewing/contract_agreement_sets_migration.sql`


## Business Key

- **Composite Key**: (`contract_id`, `group_type`)
- **Source (orchestration)**: Contract Agreement Sets (`contract_agreements` → `contract_agreement_sets`)

## Migration Notes

- Uses uuid column from source table as id (preserves legacy UUID when available)
- Maps contract_id from contract_id (bigint) via migration.table_mappings to seafarer_contracts
- Gets latest active vessel_revision_id from vessel_revision table
- Maps group_type from agreement_type: Addendum->addendum, Amendment->amendment, Original->initial
- Extracts effective_date from metadata or uses start_date/created_at
- Maps is_verified from status: true when status is "Verified", "Approved", or "Signed", else false
- Maps workflow_status_id from contract_agreements.workflow_status_id
- Maps verification_notes from notes
- Requires seafarer_contracts, vessels, and vessel_revisions to be migrated first
- seafarer_contracts is migrated from vessel_contracts in legacy
- Migrates contract_agreement_sets from contract_agreements table. Preserves legacy UUID when available (source has id bigint + uuid uuid, target has id uuid). Maps contract_id from contract_id (bigint) via migration.table_mappings to seafarer_contracts. Extracts vessel_id from vessel_info JSONB and maps via migration.table_mappings to vessels (in smac_master_migration). Gets latest active vessel_revision_id from vessel_revisions table. Maps group_type from agreement_type. Extracts effective_date from metadata->>'effective_date' or uses start_date/created_at. Maps is_verified from is_active (reverse meaning: NOT is_active). Maps verification_notes from notes. Maps expiry_date from end_date. Preserves vessel_info, seafarer_info, and family_info JSONB fields. Uses standardized SMAC audit_info structure. Requires seafarer_contracts, vessels (in smac_master_migration), and vessel_revisions (in smac_master_migration) to be migrated first.

## Special Considerations

- Extracts vessel_id from vessel_info JSONB and maps via migration.table_mappings to vessels
- Only include contract agreements that match the main query filter (same WHERE clause)
- Script performs `TRUNCATE TABLE public.contract_agreement_sets` before insert (full table reload).
- Orchestration dependencies: `seafarer_contracts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 10

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `contract_workflow_status_mapping` | Check if any mappings already exist for the given source and | `cm.legacy_id`, `sc.workflow_status_id` | - | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `contract_agreement_vessel_mapping` | FK lookup | `contract_agreement_id`, `legacy_vessel_id` | - | `synergy_manning` |
| `vessel_info_mapping` | FK lookup | `DISTINCT cavm.legacy_vessel_id`, `new_vessel_id`, `vessel_name`, `vessel_imo_number` | - | `synergy_vessel` |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `positions_id_mapping` | Create contract_agreement to vessel_id mapping with fallback | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `companies_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_revision_mapping` | FK lookup | `new_vessel_id`, `active_revision_id`, `revision_code`, `revision_name`, `revision_imo_number` | - | `smac_master_migration` |

### `contract_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `contract_workflow_status_mapping`

- **Purpose**: Check if any mappings already exist for the given source and
- **Output columns**: cm.legacy_id, sc.workflow_status_id

```sql
CREATE TEMP TABLE contract_workflow_status_mapping AS
SELECT
    cm.legacy_id,
    sc.workflow_status_id
FROM contract_id_mapping cm
INNER JOIN public.seafarer_contracts sc ON sc.id = cm.new_id
WHERE sc.workflow_status_id IS NOT NULL;
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `contract_agreement_vessel_mapping`

- **Output columns**: contract_agreement_id, legacy_vessel_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_agreement_vessel_mapping AS
SELECT DISTINCT
    ca.id AS contract_agreement_id,
    COALESCE(
        CASE
            WHEN ca.vessel_info IS NOT NULL
                 AND ca.vessel_info->>'Id' IS NOT NULL
                 AND (ca.vessel_info->>'Id') ~ '^[0-9]+$'
                 AND (ca.vessel_info->>'Id')::bigint > 0
            THEN (ca.vessel_info->>'Id')::bigint
            ELSE NULL
        END,
        vc.vessel_id
    ) AS legacy_vessel_id
FROM dblink('synergy_manning',
    'SELECT
        id,
        contract_id,
        vessel_info
     FROM public.contract_agreements
     WHERE uuid IS NOT NULL
       AND contract_id IN (
           SELECT id FROM public.vessel_contracts
           WHERE uuid IS NOT NULL
             AND deleted_at IS NULL
       )'
) AS ca(id bigint, contract_id bigint, vessel_info jsonb)
LEFT JOIN dblink('synergy_manning',
    'SELECT
        id AS vessel_contract_id,
        vessel_id
     FROM public.vessel_contracts
     WHERE vessel_id IS NOT NULL'
) AS vc(vessel_contract_id bigint, vessel_id bigint)
    ON vc.vessel_contract_id = ca.contract_id;
```

### `vessel_info_mapping`

- **Output columns**: DISTINCT cavm.legacy_vessel_id, new_vessel_id, vessel_name, vessel_imo_number
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id,
    v.name AS vessel_name,
    v.imo_number AS vessel_imo_number
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id


LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name, imo_number FROM vessel.vessels WHERE id IS NOT NULL'
) AS v(id uuid, name text, imo_number text) ON v.id = vm.new_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS tm(source_id text, target_id uuid);
```

### `positions_id_mapping`

- **Purpose**: Create contract_agreement to vessel_id mapping with fallback
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `companies_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_revision_mapping`

- **Output columns**: new_vessel_id, active_revision_id, revision_code, revision_name, revision_imo_number
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id,
    vr.code AS revision_code,
    vr.name AS revision_name,
    vim.vessel_imo_number AS revision_imo_number
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, code, name, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, code text, name text, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | uuid, id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.uuid) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_agreements'::VARCHAR(100), legacy_data.id::text, c... |
| 2 | derived | - | contract_id | - | COALESCE(contract_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as contract_id | COALESCE(contract_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | vessel_id | - | COALESCE(vim.new_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_id | COALESCE(vim.new_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | group_type | - | CASE WHEN UPPER(TRIM(agreement_type)) = 'ADDENDUM' THEN 'addendum' WHEN UPPER(TRIM(agreement_type)) = 'AMENDMENT' THEN 'amendment' WHEN UPPER(TRIM(agreement_type)) = 'ORIGINAL' ... | CASE WHEN UPPER(TRIM(agreement_type)) = 'ADDENDUM' THEN 'addendum' WHEN UPPER(TRIM(agreement_type)) = 'AMENDMENT' THEN 'amendment' WHEN UPPER(TRIM(agreement_type)) = 'ORIGINAL' ... |
| 6 | derived | - | group_reference | - | 'Initial Contract 2025-11'::text AS group_reference | 'Initial Contract 2025-11'::text |
| 7 | start_date, created_at | - | effective_date | - | COALESCE( CASE WHEN metadata->>'EffectiveFrom' IS NOT NULL AND TRIM(metadata->>'EffectiveFrom') != '' THEN (metadata->>'EffectiveFrom')::timestamp ELSE NULL END, legacy_data.sta... | COALESCE( CASE WHEN metadata->>'EffectiveFrom' IS NOT NULL AND TRIM(metadata->>'EffectiveFrom') != '' THEN (metadata->>'EffectiveFrom')::timestamp ELSE NULL END, legacy_data.sta... |
| 8 | derived | - | expiry_date | - | end_date AS expiry_date | end_date |
| 9 | vessel_info | - | vessel_info | - | CASE WHEN legacy_data.vessel_info IS NULL OR legacy_data.vessel_info::text IN ('null', '{}') OR vim.new_vessel_id IS NULL THEN NULL::jsonb ELSE jsonb_build_object( 'Id', vim.new... | CASE WHEN legacy_data.vessel_info IS NULL OR legacy_data.vessel_info::text IN ('null', '{}') OR vim.new_vessel_id IS NULL THEN NULL::jsonb ELSE jsonb_build_object( 'Id', vim.new... |
| 10 | seafarer_info | - | seafarer_info | - | CASE WHEN legacy_data.seafarer_info IS NULL OR legacy_data.seafarer_info::text IN ('null', '{}') THEN NULL::jsonb ELSE jsonb_build_object( 'Id', CASE WHEN legacy_data.seafarer_i... | CASE WHEN legacy_data.seafarer_info IS NULL OR legacy_data.seafarer_info::text IN ('null', '{}') THEN NULL::jsonb ELSE jsonb_build_object( 'Id', CASE WHEN legacy_data.seafarer_i... |
| 11 | - | - | family_info | - | NULL | NULL::jsonb |
| 12 | workflow_status_id | - | workflow_status_id | - | COALESCE(cws.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) AS workflow_status_id | COALESCE(cws.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 13 | derived | - | is_verified | - | CASE WHEN UPPER(TRIM(status)) IN ('VERIFIED', 'APPROVED', 'SIGNED') THEN true ELSE false END AS is_verified | CASE WHEN UPPER(TRIM(status)) IN ('VERIFIED', 'APPROVED', 'SIGNED') THEN true ELSE false END |
| 14 | - | - | verified_at | - | NULL | NULL::timestamp |
| 15 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 16 | derived | - | verification_notes | - | NULLIF(TRIM(notes), '') AS verification_notes | NULLIF(TRIM(notes), '') |
| 17 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL OR COALESCE(legacy_data.is_active, false) = false THEN 'Inactive' ELSE 'Active' END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL OR COALESCE(legacy_data.is_active, false) = false THEN 'Inactive' ELSE 'Active' END |
| 18 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 19 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 20 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 21 | - | - | archived_at | - | NULL | NULL::timestamp |
| 22 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 23 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_contracts`
- `seafarer_contracts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Contract Workflow Status ID Mapping
**Purpose**: Check if any mappings already exist for the given source and
**Output columns**: `cm.legacy_id, sc.workflow_status_id`

```sql
CREATE TEMP TABLE contract_workflow_status_mapping AS
SELECT
    cm.legacy_id,
    sc.workflow_status_id
FROM contract_id_mapping cm
INNER JOIN public.seafarer_contracts sc ON sc.id = cm.new_id
WHERE sc.workflow_status_id IS NOT NULL;
```

### 3. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 4. Contract Agreement Vessel ID Mapping
**Output columns**: `contract_agreement_id, legacy_vessel_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_agreement_vessel_mapping AS
SELECT DISTINCT
    ca.id AS contract_agreement_id,
    COALESCE(
        CASE
            WHEN ca.vessel_info IS NOT NULL
                 AND ca.vessel_info->>'Id' IS NOT NULL
                 AND (ca.vessel_info->>'Id') ~ '^[0-9]+$'
                 AND (ca.vessel_info->>'Id')::bigint > 0
            THEN (ca.vessel_info->>'Id')::bigint
            ELSE NULL
        END,
        vc.vessel_id
    ) AS legacy_vessel_id
FROM dblink('synergy_manning',
    'SELECT
        id,
        contract_id,
        vessel_info
     FROM public.contract_agreements
     WHERE uuid IS NOT NULL
       AND contract_id IN (
           SELECT id FROM public.vessel_contracts
           WHERE uuid IS NOT NULL
             AND deleted_at IS NULL
       )'
) AS ca(id bigint, contract_id bigint, vessel_info jsonb)
LEFT JOIN dblink('synergy_manning',
    'SELECT
        id AS vessel_contract_id,
        vessel_id
     FROM public.vessel_contracts
     WHERE vessel_id IS NOT NULL'
) AS vc(vessel_contract_id bigint, vessel_id bigint)
    ON vc.vessel_contract_id = ca.contract_id;
```

### 5. Vessel Info ID Mapping
**Output columns**: `DISTINCT cavm.legacy_vessel_id, new_vessel_id, vessel_name, vessel_imo_number`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id,
    v.name AS vessel_name,
    v.imo_number AS vessel_imo_number
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id


LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name, imo_number FROM vessel.vessels WHERE id IS NOT NULL'
) AS v(id uuid, name text, imo_number text) ON v.id = vm.new_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### 6. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS tm(source_id text, target_id uuid);
```

### 7. Positions ID Mapping
**Purpose**: Create contract_agreement to vessel_id mapping with fallback
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 8. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 9. Companies ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 10. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id, revision_code, revision_name, revision_imo_number`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id,
    vr.code AS revision_code,
    vr.name AS revision_name,
    vim.vessel_imo_number AS revision_imo_number
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, code, name, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, code text, name text, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/crewing/contract_agreement_sets_migration.sql`

## Validation

- Run `05-validation/crewing/contract_agreement_sets_validation.sql` if available
- Run `06-rollback/crewing/contract_agreement_sets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
