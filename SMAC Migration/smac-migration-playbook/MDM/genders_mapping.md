# Table Mapping: gender → genders

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: gender
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: genders
- **Source Script**: `04-migration-scripts/master/genders_migration.sql`

- **Legacy Path**: `synergy_master.enum.gender`
- **New Path**: `smac_master_migration.public.genders`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Gender (`gender` → `genders`)

## Migration Notes

- Preserve legacy identifier (UUID) as id if available, otherwise generate new UUID
- Uses migration.resolve_target_id() for idempotent UUID generation
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.genders` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'gender'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'public'... |
| 2 | name | - | code | - | CASE WHEN UPPER(TRIM(legacy_data.name)) = 'MALE' THEN 'M' WHEN UPPER(TRIM(legacy_data.name)) = 'FEMALE' THEN 'F' WHEN UPPER(TRIM(legacy_data.name)) IN ('OTHER', 'OTHERS') THEN '... | CASE WHEN UPPER(TRIM(legacy_data.name)) = 'MALE' THEN 'M' WHEN UPPER(TRIM(legacy_data.name)) = 'FEMALE' THEN 'F' WHEN UPPER(TRIM(legacy_data.name)) IN ('OTHER', 'OTHERS') THEN '... |
| 3 | name | - | name | - | TRIM(legacy_data.name) AS name | TRIM(legacy_data.name) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | level | - | 0 AS level | 0 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 13 | name | - | tags | - | CASE WHEN LOWER( CASE WHEN UPPER(TRIM(legacy_data.name)) = 'MALE' THEN 'M' WHEN UPPER(TRIM(legacy_data.name)) = 'FEMALE' THEN 'F' WHEN UPPER(TRIM(legacy_data.name)) IN ('OTHER',... | CASE WHEN LOWER( CASE WHEN UPPER(TRIM(legacy_data.name)) = 'MALE' THEN 'M' WHEN UPPER(TRIM(legacy_data.name)) = 'FEMALE' THEN 'F' WHEN UPPER(TRIM(legacy_data.name)) IN ('OTHER',... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/genders_migration.sql`

## Validation

- Run `05-validation/master/genders_validation.sql` if available
- Run `06-rollback/master/genders_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
