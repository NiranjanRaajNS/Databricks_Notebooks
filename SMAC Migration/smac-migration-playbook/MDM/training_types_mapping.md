# Table Mapping: training_types → training_type

## Overview
- **Legacy Database**: synergy_training
- **Legacy Schema**: public
- **Legacy Table**: training_types
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: training_type
- **Source Script**: `04-migration-scripts/master/training_types_migration.sql`

- **Legacy Path**: `synergy_training.public.training_types`
- **New Path**: `smac_crewing_migration.crewing.training_type`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Training Types (`training_types` → `training_type`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates training_types from synergy_training.public.training_types to smac_crewing_migration.crewing.training_type. Preserves legacy UUID (id) as target id using migration.resolve_target_id(). Generates code using generate_meaningful_code() from name. Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Converts timestamps from timestamp with time zone to timestamp without time zone. Stores created_by_id, updated_by_id, deleted_by_id, created_by_name, updated_by_name, deleted_by_name in audit_info JSONB. Uses standardized SMAC audit_info structure. This is a master/reference table that must be migrated before training_master.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.training_type` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_training'::VARCHAR(100), 'public'::VARCHAR(100), 'training_types'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | name, id | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(COALESCE(legacy_data.name, 'UNKNOWN')), legacy_data.id::text) |
| 3 | name | - | name | - | TRIM(COALESCE(legacy_data.name, 'UNKNOWN')) as name | TRIM(COALESCE(legacy_data.name, 'UNKNOWN')) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 7 | derived | - | level | - | 0 as level | 0 |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW())::timestamp without time zone as created_at | COALESCE(legacy_data.created_at, NOW())::timestamp without time zone |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW())::timestamp without time zone as updated_at | COALESCE(legacy_data.updated_at, NOW())::timestamp without time zone |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at::timestamp without time zone as deleted_at | legacy_data.deleted_at::timestamp without time zone |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp without time zone |
| 16 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name, deleted_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |
| 17 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/training_types_migration.sql`

## Validation

- Run `05-validation/master/training_types_validation.sql` if available
- Run `06-rollback/master/training_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
