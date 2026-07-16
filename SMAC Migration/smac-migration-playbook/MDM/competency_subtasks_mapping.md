# Table Mapping: competency_subtasks → competency_subtasks

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_subtasks
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_subtasks
- **Source Script**: `04-migration-scripts/master/competency_subtasks_migration.sql`

- **Legacy Path**: `efr.public.competency_subtasks`
- **New Path**: `smac_master_migration.crewing.competency_subtasks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Competency Subtasks (`competency_subtasks` → `competency_subtasks`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.competency_subtasks` before insert (full table reload).
- Orchestration dependencies: `competency_tasks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `competency_tasks_id_mapping` | Check i | `legacy_taskid`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `competency_tasks_id_mapping`

- **Purpose**: Check i
- **Output columns**: legacy_taskid, new_id
- **migration.table_mappings**: target_table=competency_tasks

```sql
CREATE TEMP TABLE competency_tasks_id_mapping AS
SELECT DISTINCT
    tm.target_id::text as legacy_taskid,
    ct.id as new_id
FROM migration.table_mappings tm
INNER JOIN crewing.competency_tasks ct ON ct.id = tm.target_id
WHERE tm.target_table = 'competency_tasks'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, sub_task_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'efr'::VARCHAR(100), 'public'::VARCHAR(100), 'competency_subtasks'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'cre... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, NULL) |
| 3 | derived | - | task_id | - | task_mapping.new_id as task_id | task_mapping.new_id |
| 4 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 5 | derived | - | description | - | TRIM(description) as description | TRIM(description) |
| 6 | derived | - | guidelines | - | TRIM(guidelines) as guidelines | TRIM(guidelines) |
| 7 | derived | - | assessment_details | - | TRIM(assessment_details) as assessment_details | TRIM(assessment_details) |
| 8 | derived | - | level | - | 0 as level | 0 |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 15 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 17 | created_by_id, deleted_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Competency Tasks ID Mapping
**Purpose**: Check i
**Output columns**: `legacy_taskid, new_id`
**migration.table_mappings**: `target_table='competency_tasks'`

```sql
CREATE TEMP TABLE competency_tasks_id_mapping AS
SELECT DISTINCT
    tm.target_id::text as legacy_taskid,
    ct.id as new_id
FROM migration.table_mappings tm
INNER JOIN crewing.competency_tasks ct ON ct.id = tm.target_id
WHERE tm.target_table = 'competency_tasks'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/competency_subtasks_migration.sql`

## Validation

- Run `05-validation/master/competency_subtasks_validation.sql` if available
- Run `06-rollback/master/competency_subtasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
