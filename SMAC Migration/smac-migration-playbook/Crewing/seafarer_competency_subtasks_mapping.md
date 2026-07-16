# Table Mapping: seafarer_competency_subtasks → seafarer_competency_subtasks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_subtasks
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_subtasks
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_subtasks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_subtasks`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_subtasks`

## Business Key

- **Composite Key**: (`competency_id`, `subtask_id`, `seafarer_uuid`)
- **Source (orchestration)**: Seafarer Competency Subtasks (`seafarer_competency_subtasks` → `seafarer_competency_subtasks`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_competency_subtasks table. Maps competency_id to seafarer_task_id via migration.table_mappings. Maps seafarer_uuid to seafarer_id using direct join. Converts jsonb fields (comments, history, attachment_ids) to text. Adds required tenant_id, workflow_status_id, and is_verified fields.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_subtasks` before insert (full table reload).
- Orchestration dependencies: `seafarer_competency_tasks`, `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_competency_subtasks'::VARCHAR(100), legacy_data.id:... |
| 2 | task_id | - | seafarer_task_id | - | legacy_data.task_id as seafarer_task_id | legacy_data.task_id |
| 3 | subtask_id | - | subtask_id | - | legacy_data.subtask_id as subtask_id | legacy_data.subtask_id |
| 4 | seafarer_uuid | - | seafarer_id | - | legacy_data.seafarer_uuid as seafarer_id | legacy_data.seafarer_uuid |
| 5 | comments | - | comments | - | CASE WHEN legacy_data.comments IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.comments) = 'string' THEN legacy_data.comments::text ELSE legacy_data.comments::text END as comments | CASE WHEN legacy_data.comments IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.comments) = 'string' THEN legacy_data.comments::text ELSE legacy_data.comments::text END |
| 6 | history | - | history | - | CASE WHEN legacy_data.history IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.history) = 'string' THEN legacy_data.history::text ELSE legacy_data.history::text END as history | CASE WHEN legacy_data.history IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.history) = 'string' THEN legacy_data.history::text ELSE legacy_data.history::text END |
| 7 | attachment_ids | - | attachment_ids | - | CASE WHEN legacy_data.attachment_ids IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.attachment_ids) = 'string' THEN legacy_data.attachment_ids::text ELSE legacy_data.attachment... | CASE WHEN legacy_data.attachment_ids IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.attachment_ids) = 'string' THEN legacy_data.attachment_ids::text ELSE legacy_data.attachment... |
| 8 | derived | - | workflow_status_id | - | COALESCE( (SELECT id FROM default_workflow_status), '00000000-0000-0000-0000-000000000000'::uuid ) as workflow_status_id | COALESCE( (SELECT id FROM default_workflow_status), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 9 | derived | - | is_verified | - | FALSE as is_verified | FALSE |
| 10 | derived | - | verified_at | - | NULL as verified_at | NULL |
| 11 | derived | - | verified_by_id | - | NULL as verified_by_id | NULL |
| 12 | derived | - | verification_notes | - | NULL as verification_notes | NULL |
| 13 | status | - | status | - | TRIM(COALESCE(legacy_data.status, '')) as status | TRIM(COALESCE(legacy_data.status, '')) |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 16 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 17 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 18 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 19 | created_by_id, deleted_by_id, updated_by_id, approved_on, approved_by, rejected_by, created_by_name, updated_by_name, task_id, seafarer_uuid | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, legacy_data... |
| 20 | derived | - | name | - | NULL as name | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_competency_subtasks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_subtasks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_subtasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
