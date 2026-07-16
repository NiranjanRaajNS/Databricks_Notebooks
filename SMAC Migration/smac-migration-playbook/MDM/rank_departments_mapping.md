# Table Mapping: rank_departments → rank_departments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: rank_departments
- **Source Script**: `04-migration-scripts/master/rank_departments_migration.sql`


## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- Extract distinct values from department column in ranks table
- Uses migration.resolve_target_id() for idempotent UUID generation
- Record legacy value → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Duplicate UUID check not applicable - source is text column (department), not UUID column
- TRUNCATE public.departments then copy from smac_master_migration.public.departments (dblink). Clears migration.table_mappings for departments/Department. Preserves UUIDs for FK alignment with designations from master.

## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_departments` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | department_name | - | id | - | migration.resolve_target_id() | DISTINCT ON (LOWER(TRIM(legacy_data.department_name))) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ranks'::VARCHAR(100), legacy_data.de... |
| 2 | department_name | - | code | - | CASE WHEN UPPER(TRIM(legacy_data.department_name)) = 'ENGINE' OR UPPER(TRIM(legacy_data.department_name)) = 'ENGINEERING' THEN 'ENG' WHEN UPPER(TRIM(legacy_data.department_name)... | CASE WHEN UPPER(TRIM(legacy_data.department_name)) = 'ENGINE' OR UPPER(TRIM(legacy_data.department_name)) = 'ENGINEERING' THEN 'ENG' WHEN UPPER(TRIM(legacy_data.department_name)... |
| 3 | department_name | - | name | - | TRIM(legacy_data.department_name) AS name | TRIM(legacy_data.department_name) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | level | - | 0 AS level | 0 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/rank_departments_migration.sql`

## Validation

- Run `05-validation/master/rank_departments_validation.sql` if available
- Run `06-rollback/master/rank_departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
