# Table Mapping: religions → religions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: religions
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: religions
- **Source Script**: `04-migration-scripts/master/religions_migration.sql`

- **Legacy Path**: `synergy_master.public.religions`
- **New Path**: `smac_master_migration.public.religions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Religions (`religions` → `religions`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.religions` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'religions'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'pu... |
| 2 | name | - | code | - | CASE WHEN UPPER(TRIM(legacy_data.name)) = 'HINDU' THEN 'HIN' WHEN UPPER(TRIM(legacy_data.name)) = 'CHRISTIANITY' OR UPPER(TRIM(legacy_data.name)) = 'CHRISTIAN' THEN 'CHR' WHEN U... | CASE WHEN UPPER(TRIM(legacy_data.name)) = 'HINDU' THEN 'HIN' WHEN UPPER(TRIM(legacy_data.name)) = 'CHRISTIANITY' OR UPPER(TRIM(legacy_data.name)) = 'CHRISTIAN' THEN 'CHR' WHEN U... |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | name | - | level | - | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name)) as level | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name)) |
| 11 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/religions_migration.sql`

## Validation

- Run `05-validation/master/religions_validation.sql` if available
- Run `06-rollback/master/religions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
