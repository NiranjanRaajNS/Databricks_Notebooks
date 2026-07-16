# Table Mapping: contract_agreement_sets → contract_agreement_sets

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_agreements
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: contract_agreement_sets
- **Source Script**: `04-migration-scripts/crewing/contract_agreement_sets_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_agreements`
- **New Path**: `smac_crewing_migration.public.contract_agreement_sets`

## Business Key

- **Composite Key**: (`contract_id`, `group_type`)
- **Source (orchestration)**: Contract Agreement Sets (`contract_agreements` → `contract_agreement_sets`)

## Migration Notes

- SAC `contract_agreements` (filtered: `uuid IS NOT NULL`, parent `vessel_contracts` active) → SMAC `contract_agreement_sets`
- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`; `DISTINCT ON (uuid)`
- `contract_id` mapped via `contract_id_mapping` → `seafarer_contracts`
- Vessel resolved from `vessel_info->>'Id'` or `vessel_contracts.vessel_id`; mapped via `vessel_id_mapping` (dblink `smac_master_migration`)
- `vessel_revision_id` = latest active revision (`status = 0`) per vessel from `vessel.vessel_revisions`
- `group_type` from `agreement_type` (Addendum/Amendment/Original → addendum/amendment/initial)
- `workflow_status_id` inherited from mapped `seafarer_contracts.workflow_status_id`
- `vessel_info` / `seafarer_info` JSONB rebuilt with mapped UUIDs (ranks, seafarers lookups)
- `family_info` set to NULL; `group_reference` hardcoded
- Requires `seafarer_contracts`, `vessels`, `vessel_revisions`, `seafarers`, `ranks` migrated first

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
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | `DISTINCT ON (uuid)`; preserves SAC UUID |
| 2 | `contract_id` | bigint | `contract_id` | uuid | Map via `contract_id_mapping`; default nil UUID | Lookup: `seafarer_contracts` mappings |
| 3 | `vessel_info`, `contract_id` | jsonb, bigint | `vessel_id` | uuid | Resolve legacy vessel id from JSONB or contract; map via `vessel_info_mapping` | Lookup: `vessels` via dblink `smac_master_migration` |
| 4 | `vessel_id` (mapped) | uuid | `vessel_revision_id` | uuid | Latest active revision per vessel from `vessel_revision_mapping` | Lookup: `vessel.vessel_revisions` where `status = 0` |
| 5 | `agreement_type` | text | `group_type` | text | ADDENDUM→`addendum`, AMENDMENT→`amendment`, ORIGINAL→`initial`; else lowercase | NOT NULL |
| 6 | — | — | `group_reference` | text | Hardcoded `'Initial Contract 2025-11'` | Not from SAC column |
| 7 | `metadata`, `start_date`, `created_at` | jsonb, timestamp | `effective_date` | timestamp without time zone | `metadata->>'EffectiveFrom'` → `start_date` → `created_at` → `NOW()` | NOT NULL |
| 8 | `end_date` | timestamp | `expiry_date` | timestamp without time zone | Direct copy | Nullable |
| 9 | `vessel_info` | jsonb | `vessel_info` | jsonb | Rebuild JSONB with mapped vessel UUID, revision code/name, IMO | NULL when source empty or vessel unmapped |
| 10 | `seafarer_info` | jsonb | `seafarer_info` | jsonb | Rebuild JSONB; map `Id`/`RankId` integers via seafarers/ranks lookups; split `Name` → First/Last | NULL when source empty |
| 11 | `family_info` | jsonb | `family_info` | jsonb | `NULL` | SAC `family_info` not migrated |
| 12 | `contract_id` (via contract) | — | `workflow_status_id` | uuid | From `contract_workflow_status_mapping` (parent contract's workflow status) | Lookup: `seafarer_contracts.workflow_status_id` |
| 13 | `status` | character varying | `is_verified` | boolean | `VERIFIED`/`APPROVED`/`SIGNED` → true; else false | Derived from agreement status text |
| 14 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 15 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC |
| 16 | `notes` | text | `verification_notes` | text | `NULLIF(TRIM(notes), '')` | Nullable |
| 17 | `deleted_at`, `is_active` | timestamp, boolean | `status` | text | `deleted_at IS NOT NULL` OR `is_active = false` → `Inactive`; else `Active` | Text status |
| 18 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 19 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 20 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | NOT NULL |
| 21 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 22 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 23 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | No `legacy_id` (UUID preserved as `id`) |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `external_agreement_id`, `agreement_no`, `wages_info`, `terms`, `cba`, `agreement_file_path`, `is_digitally_signed`, `position_id`, `task_id`, `place_of_engagement`, `source`, `revised_salary_info`, `poseidon_agreement_file_path`, `poseidon_wages_info` — not referenced in `contract_agreement_sets` INSERT (migrated in `contract_agreements` script).

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
