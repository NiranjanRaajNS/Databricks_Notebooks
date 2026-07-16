# Table Mapping: competency_task_rejection_reasons → competency_task_rejection_reasons

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_task_rejection_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_task_rejection_reasons
- **Source Script**: `04-migration-scripts/master/competency_task_rejection_reasons_migration.sql`

- **Legacy Path**: `efr.public.competency_task_rejection_reasons`
- **New Path**: `smac_master_migration.crewing.competency_task_rejection_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Competency Task Rejection Reasons (`competency_task_rejection_reasons` → `competency_task_rejection_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.competency_task_rejection_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'efr'::VARCHAR(100), 'public'::VARCHAR(100), 'competency_task_rejection_reasons'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | description | - | TRIM(description) as description | TRIM(description) |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at, isdeleted | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.isdeleted IS NULL THEN 0 WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.isdeleted IS NULL THEN 0 WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 12 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 14 | created_by_id, deleted_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/competency_task_rejection_reasons_migration.sql`

## Validation

- Run `05-validation/master/competency_task_rejection_reasons_validation.sql` if available
- Run `06-rollback/master/competency_task_rejection_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
