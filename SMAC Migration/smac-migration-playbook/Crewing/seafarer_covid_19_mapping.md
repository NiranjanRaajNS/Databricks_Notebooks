# Table Mapping: seafarer_covid_19 → seafarer_covid_19

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_covid_19
- **Source Script**: `04-migration-scripts/crewing/seafarer_covid_19_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer COVID-19 (`seafarer_covid19s` → `seafarer_covid_19`)

## Migration Notes

- Uses integer values for vaccine_status (see constants.sql)
- vaccine_id mapping queries from smac_master_migration.migration.table_mappings via dblink
- seafarer_id mapping queries from current database (smac_crewing_migration) migration.table_mappings
- Migrates seafarer_covid19s to seafarer_covid_19 table. Generates new UUIDs for id column (legacy id stored in mapping table). Maps seafarer_id (bigint) to uuid via migration.table_mappings from smac_crewing_migration. Maps vaccine_id (bigint) to uuid via migration.table_mappings from smac_master_migration (optional). Converts reason from integer to text. Converts other_plan_date from date to timestamp. Generates UUID for seafarer_document_id (not in source). Sets doses to NULL (not in source). Handles NULL values: seafarer_id generates UUID if mapping not found, vaccine_status defaults to 0 if NULL.

## Special Considerations

- Generates new UUIDs for id (no identifier/uuid in source), maps seafarer_id and vaccine_id via migration.table_mappings
- Script performs `TRUNCATE TABLE shared.seafarer_covid_19` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vaccines`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vaccines_id_mapping` | FK lookup | `legacy_id::text`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `vaccines_id_mapping`

- **Output columns**: legacy_id::text, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vaccines_id_mapping AS
SELECT
    legacy_id::text,
    new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''vaccines'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 2 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 3 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | vaccine_id | - | vaccine_mapping.new_id as vaccine_id | vaccine_mapping.new_id |
| 5 | derived | - | seafarer_document_id | - | '00000000-0000-0000-0000-000000000000'::uuid as seafarer_document_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 6 | - | - | doses | - | NULL | NULL::jsonb |
| 7 | reason | - | reason | - | CASE WHEN legacy_data.reason IS NULL THEN NULL ELSE legacy_data.reason::text END as reason | CASE WHEN legacy_data.reason IS NULL THEN NULL ELSE legacy_data.reason::text END |
| 8 | vaccination_status | - | vaccine_status | - | COALESCE(legacy_data.vaccination_status, 0) as vaccine_status | COALESCE(legacy_data.vaccination_status, 0) |
| 9 | other_plan_date | - | other_planned_date | - | CASE WHEN legacy_data.other_plan_date IS NULL THEN NULL ELSE legacy_data.other_plan_date::timestamp END as other_planned_date | CASE WHEN legacy_data.other_plan_date IS NULL THEN NULL ELSE legacy_data.other_plan_date::timestamp END |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 12 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | created_by_id, updated_by_id, id | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Vaccines ID Mapping
**Output columns**: `legacy_id::text, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vaccines_id_mapping AS
SELECT
    legacy_id::text,
    new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''vaccines'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_covid_19_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_covid_19_validation.sql` if available
- Run `06-rollback/crewing/seafarer_covid_19_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
