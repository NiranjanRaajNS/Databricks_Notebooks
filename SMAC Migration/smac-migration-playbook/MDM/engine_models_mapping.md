# Table Mapping: engine_model → engine_models

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: engine_model
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: engine_models
- **Source Script**: `04-migration-scripts/master/engine_models_migration.sql`

- **Legacy Path**: `synergy_vessel.public.engine_model`
- **New Path**: `smac_master_migration.vessel.engine_models`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Engine Model (`engine_model` → `engine_models`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.engine_models` before insert (full table reload).
- Orchestration dependencies: `engine_makes`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `engine_make_id_mapping` | Check for duplicate UUIDs in source table | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `engine_make_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=engine_makes

```sql
CREATE TEMP TABLE engine_make_id_mapping AS
SELECT
    source_id::text AS source_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'engine_makes'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'engine_model'::VARCHAR(100), legacy_data.identifier::text, current_database()::text::VARCHA... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(COALESCE(TRIM(legacy_data.name), 'UNKNOWN'), legacy_data.identifier::text) |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') AS name | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') |
| 4 | description | - | description | - | NULLIF(TRIM(REGEXP_REPLACE(COALESCE(legacy_data.description, ''), '</?p>', '', 'gi')), '') AS description | NULLIF(TRIM(REGEXP_REPLACE(COALESCE(legacy_data.description, ''), '</?p>', '', 'gi')), '') |
| 5 | derived | - | engine_make_id | - | emm.target_id AS engine_make_id | emm.target_id |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Engine Make ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `target_table='engine_makes'`

```sql
CREATE TEMP TABLE engine_make_id_mapping AS
SELECT
    source_id::text AS source_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'engine_makes'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/engine_models_migration.sql`

## Validation

- Run `05-validation/master/engine_models_validation.sql` if available
- Run `06-rollback/master/engine_models_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
