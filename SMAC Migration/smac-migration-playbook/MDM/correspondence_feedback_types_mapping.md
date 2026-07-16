# Table Mapping: feedback_correspondence_types → correspondence_feedback_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: feedback_correspondence_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: correspondence_feedback_types
- **Source Script**: `04-migration-scripts/master/correspondence_feedback_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.feedback_correspondence_types`
- **New Path**: `smac_master_migration.crewing.correspondence_feedback_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Feedbackreasontype (`feedbackreasontype` → `correspondence_feedback_types`)

## Migration Notes

- No identifier/uuid column in source table - use migration.resolve_target_id() for idempotent UUID generation
- Record legacy id (integer) → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates feedbackreasontype preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.correspondence_feedback_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'feedback_correspondence_types'::VARCHAR(100), legacy_data.id::text, current_database()::t... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 as status | 0 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 11 | id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/correspondence_feedback_types_migration.sql`

## Validation

- Run `05-validation/master/correspondence_feedback_types_validation.sql` if available
- Run `06-rollback/master/correspondence_feedback_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
