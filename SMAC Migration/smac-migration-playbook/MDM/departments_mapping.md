# Table Mapping: "Department" → departments

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Department"
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: departments
- **Source Script**: `04-migration-scripts/master/departments_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Department"`
- **New Path**: `smac_master_migration.public.departments`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Departments (`department` → `departments`)

## Migration Notes

- Source table name is case-sensitive: "Department" (with quotes)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates departments table

## Special Considerations

- Script performs `TRUNCATE TABLE public.departments` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_identity_shore_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Department'::VARCHAR(100), legacy_data.id::text, current_database()::text::VAR... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | codename, name | - | code | - | generate_meaningful_code() | COALESCE( NULLIF(TRIM(legacy_data.codename), ''), generate_meaningful_code(UPPER(TRIM(legacy_data.name)), NULL) ) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 as status | 0 |
| 9 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 11 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 12 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | codename, name | - | tags | - | generate_meaningful_code() | CASE WHEN LOWER(COALESCE(NULLIF(TRIM(legacy_data.codename), ''), generate_meaningful_code(UPPER(TRIM(legacy_data.name)), NULL))) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(le... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/departments_migration.sql`

## Validation

- Run `05-validation/master/departments_validation.sql` if available
- Run `06-rollback/master/departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
