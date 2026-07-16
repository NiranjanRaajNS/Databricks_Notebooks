# Table Mapping: appraisal_types → appraisal_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: appraisal_types
- **Source Script**: `04-migration-scripts/master/appraisal_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_types`
- **New Path**: `smac_master_migration.crewing.appraisal_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Types (`appraisal_types` → `appraisal_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.appraisal_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'appraisal_types'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | description | - | CASE WHEN description IS NULL THEN NULL WHEN TRIM(description) = '' THEN NULL ELSE TRIM(description) END as description | CASE WHEN description IS NULL THEN NULL WHEN TRIM(description) = '' THEN NULL ELSE TRIM(description) END |
| 5 | derived | - | level | - | COALESCE(position, 0) as level | COALESCE(position, 0) |
| 6 | - | - | appraisal_mode | - | NULL | NULL::integer |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | is_active | - | status | - | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END |
| 12 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 14 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |
| 15 | derived | - | requires_objective_setup | - | false as requires_objective_setup | false |
| 16 | derived | - | requires_confirmation_stage | - | false as requires_confirmation_stage | false |
| 17 | name | - | auto_initiate_on_event | - | CASE WHEN TRIM(legacy_data.name) = 'Sign Off' THEN 1 ELSE NULL END as auto_initiate_on_event | CASE WHEN TRIM(legacy_data.name) = 'Sign Off' THEN 1 ELSE NULL END |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/appraisal_types_migration.sql`

## Validation

- Run `05-validation/master/appraisal_types_validation.sql` if available
- Run `06-rollback/master/appraisal_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
