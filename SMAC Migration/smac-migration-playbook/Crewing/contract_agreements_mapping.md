# Table Mapping: contract_agreements → contract_agreements

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: contract_agreements
- **Source Script**: `04-migration-scripts/crewing/contract_agreements_migration.sql`


## Business Key

- **Business Key**: `vr.vessel_id`
- **Source (orchestration)**: Update Contract Agreements Agreement Group ID (`contract_agreements` → `contract_agreements`)

## Migration Notes

- Uses uuid column from source table as id (preserves legacy UUID when available)
- Maps contract_id from contract_id (bigint) via migration.table_mappings to seafarer_contracts
- Maps agreement_group_id from contract_agreement_sets.id via migration.table_mappings (requires contract_agreement_sets to be migrated first)
- Generates UUIDs for required fields: vessel_id, vessel_revision_id, workflow_status_id
- Sets default values for required fields: jurisdiction_type, is_mandatory, effective_date, agreement_status, currency_code
- Extracts user IDs from created_by_id, updated_by_id to audit_info
- Uses text values for status
- Requires seafarer_contracts (vessel_contracts in legacy) and contract_agreement_sets to be migrated first
- seafarer_contracts is migrated from vessel_contracts in legacy
- Post-migration update script: Backfills agreement_group_id in contract_agreements table. Maps legacy contract_agreements.id to contract_agreement_sets.id via migration.table_mappings. Must run AFTER both contract_agreements and contract_agreement_sets migrations are complete.

## Special Considerations

- Converts terms from text to jsonb
- Include ALL contract agreements, even if vessel_id is NULL (for proper LEFT JOIN)
- Script performs `TRUNCATE TABLE public.contract_agreements` before insert (full table reload).
- Orchestration dependencies: `contract_agreements`, `contract_agreement_sets`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `contract_agreement_vessel_mapping` | If no mappings found in current database, try via dblink to other databases | `contract_agreement_id`, `legacy_vessel_id` | - | `synergy_manning` |
| `vessel_info_mapping` | FK lookup | `DISTINCT cavm.legacy_vessel_id`, `new_vessel_id` | - | `synergy_vessel` |
| `vessel_revision_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |

### `contract_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
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

- **Purpose**: If no mappings found in current database, try via dblink to other databases
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
     WHERE contract_id IN (
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

- **Output columns**: DISTINCT cavm.legacy_vessel_id, new_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### `vessel_revision_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_agreements'::VARCHAR(100), distinct_legacy_data.id::text, current_database()::tex... |
| 2 | mapped_contract_id | - | contract_id | - | COALESCE(distinct_legacy_data.mapped_contract_id, '00000000-0000-0000-0000-000000000000'::uuid) as contract_id | COALESCE(distinct_legacy_data.mapped_contract_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | mapped_agreement_group_id | - | agreement_group_id | - | COALESCE(distinct_legacy_data.mapped_agreement_group_id, '00000000-0000-0000-0000-000000000000'::uuid) AS agreement_group_id | COALESCE(distinct_legacy_data.mapped_agreement_group_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | mapped_vessel_id | - | vessel_id | - | COALESCE(distinct_legacy_data.mapped_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_id | COALESCE(distinct_legacy_data.mapped_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | mapped_vessel_revision_id | - | vessel_revision_id | - | COALESCE(distinct_legacy_data.mapped_vessel_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(distinct_legacy_data.mapped_vessel_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | agreement_no, id | - | agreement_no | - | COALESCE(NULLIF(TRIM(distinct_legacy_data.agreement_no), ''), 'AGREEMENT_' || distinct_legacy_data.id::text) AS agreement_no | COALESCE(NULLIF(TRIM(distinct_legacy_data.agreement_no), ''), 'AGREEMENT_' || distinct_legacy_data.id::text) |
| 7 | agreement_type | - | agreement_type | - | TRIM(distinct_legacy_data.agreement_type) AS agreement_type | TRIM(distinct_legacy_data.agreement_type) |
| 8 | derived | - | jurisdiction_type | - | 'NORMAL' AS jurisdiction_type | 'NORMAL' |
| 9 | derived | - | is_mandatory | - | false AS is_mandatory | false |
| 10 | start_date | - | start_date | - | distinct_legacy_data.start_date AS start_date | distinct_legacy_data.start_date |
| 11 | end_date | - | end_date | - | distinct_legacy_data.end_date AS end_date | distinct_legacy_data.end_date |
| 12 | metadata, start_date, created_at | - | effective_date | - | COALESCE( CASE WHEN distinct_legacy_data.metadata->>'EffectiveFrom' IS NOT NULL THEN (distinct_legacy_data.metadata->>'EffectiveFrom')::timestamp ELSE NULL END, distinct_legacy_... | COALESCE( CASE WHEN distinct_legacy_data.metadata->>'EffectiveFrom' IS NOT NULL THEN (distinct_legacy_data.metadata->>'EffectiveFrom')::timestamp ELSE NULL END, distinct_legacy_... |
| 13 | status, is_active, metadata | - | is_active | - | CASE WHEN UPPER(TRIM(distinct_legacy_data.status)) = 'SIGNED' AND COALESCE(distinct_legacy_data.is_active, false) = true AND distinct_legacy_data.metadata->>'Effective | CASE WHEN UPPER(TRIM(distinct_legacy_data.status)) = 'SIGNED' AND COALESCE(distinct_legacy_data.is_active, false) = true AND distinct_legacy_data.metadata->>'Effective |
| 14 | - | - | wage_scale_id | - | See source script | See source script |
| 15 | - | - | wage_info | - | See source script | See source script |
| 16 | - | - | proposed_wage | - | See source script | See source script |
| 17 | - | - | revised_salary | - | See source script | See source script |
| 18 | - | - | currency_code | - | See source script | See source script |
| 19 | - | - | exchange_rate | - | See source script | See source script |
| 20 | - | - | terms | - | See source script | See source script |
| 21 | - | - | cba_id | - | See source script | See source script |
| 22 | - | - | agreement_file_path | - | See source script | See source script |
| 23 | - | - | is_digitally_signed | - | See source script | See source script |
| 24 | - | - | signing_provider | - | See source script | See source script |
| 25 | - | - | metadata | - | See source script | See source script |
| 26 | - | - | agreement_status | - | See source script | See source script |
| 27 | - | - | workflow_status_id | - | See source script | See source script |
| 28 | - | - | is_verified | - | See source script | See source script |
| 29 | - | - | verified_at | - | See source script | See source script |
| 30 | - | - | verified_by_id | - | See source script | See source script |
| 31 | - | - | verification_notes | - | See source script | See source script |
| 32 | - | - | status | - | See source script | See source script |
| 33 | - | - | tenant_id | - | See source script | See source script |
| 34 | - | - | created_at | - | See source script | See source script |
| 35 | - | - | updated_at | - | See source script | See source script |
| 36 | - | - | archived_at | - | See source script | See source script |
| 37 | - | - | deleted_at | - | See source script | See source script |
| 38 | - | - | audit_info | - | See source script | See source script |
| 39 | - | - | external_agreement_id | - | See source script | See source script |
| 40 | - | - | rpsl_company_id | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_agreement_sets`
- `public.contract_agreement_sets`
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
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Vessel ID Mapping
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

### 3. Contract Agreement Vessel ID Mapping
**Purpose**: If no mappings found in current database, try via dblink to other databases
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
     WHERE contract_id IN (
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

### 4. Vessel Info ID Mapping
**Output columns**: `DISTINCT cavm.legacy_vessel_id, new_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### 5. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/crewing/contract_agreements_migration.sql`

## Validation

- Run `05-validation/crewing/contract_agreements_validation.sql` if available
- Run `06-rollback/crewing/contract_agreements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
