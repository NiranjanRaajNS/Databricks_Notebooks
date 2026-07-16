# Table Mapping: functionalities → modules

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: functionalities
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: modules
- **Source Script**: `04-migration-scripts/master/modules_migration.sql`

- **Legacy Path**: `synergy_master.public.functionalities`
- **New Path**: `smac_master_migration.public.modules`

## Business Key

- **Business Key**: `source_id`

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE public.modules` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 3 | derived | - | code | - | UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_')) as code | UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_')) |
| 4 | derived | - | is_display_required | - | TRUE as is_display_required | TRUE |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 12 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/modules_migration.sql`

## Validation

- Run `05-validation/master/modules_validation.sql` if available
- Run `06-rollback/master/modules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
