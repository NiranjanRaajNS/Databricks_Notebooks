# Table Mapping: seafarer_competency_task_activities → seafarer_competency_task_activities

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_task_activities
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_task_activities
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_task_activities_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_task_activities`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_task_activities`

## Business Key

- **Business Key**: `seafarer_task_id`
- **Source (orchestration)**: Seafarer Competency Task Activities (`seafarer_competency_task_activities` → `seafarer_competency_task_activities`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_competency_task_activities table. Maps seafarer_task_id via migration.table_mappings. Converts data from jsonb to text. Adds required tenant_id and status fields.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_task_activities` before insert (full table reload).
- Orchestration dependencies: `seafarer_competency_tasks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_competency_tasks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_competency_tasks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_competency_tasks

```sql
CREATE TEMP TABLE seafarer_competency_tasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_tasks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_competency_task_activities'::VARCHAR(100), legacy_d... |
| 2 | derived | - | seafarer_task_id | - | sct_map.new_id as seafarer_task_id | sct_map.new_id |
| 3 | data | - | data | - | COALESCE( transformed_data.transformed_json::text, CASE WHEN legacy_data.data IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.data) = 'string' THEN legacy_data.data::text ELSE l... | COALESCE( transformed_data.transformed_json::text, CASE WHEN legacy_data.data IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.data) = 'string' THEN legacy_data.data::text ELSE l... |
| 4 | status | - | status | - | TRIM(COALESCE(legacy_data.status, '')) as status | TRIM(COALESCE(legacy_data.status, '')) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 7 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 8 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 9 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 10 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name, seafarer_task_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |
| 11 | derived | - | name | - | NULL as name | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Competency Tasks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_competency_tasks'`

```sql
CREATE TEMP TABLE seafarer_competency_tasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_tasks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_competency_task_activities_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_task_activities_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_task_activities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
