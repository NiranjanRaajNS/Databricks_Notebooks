# Table Mapping: seafarer_activity_log_types → activity_log_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_log_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: activity_log_types
- **Source Script**: `04-migration-scripts/master/activity_log_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_log_types`
- **New Path**: `smac_master_migration.crewing.activity_log_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Activity Log Types (`seafarer_activity_log_types` → `activity_log_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Using CASCADE to handle foreign key dependencies (e.g., activity_log_sub_types)
- Migrates seafarer_activity_log_types preserving identifier UUID as id if available

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.activity_log_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_activity_log_types'::VARCHAR(100), legacy_data.id::text, current_database()::tex... |
| 2 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 3 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), NULL) |
| 4 | derived | - | description | - | COALESCE(TRIM(description), NULL) as description | COALESCE(TRIM(description), NULL) |
| 5 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | CASE WHEN is_active IS NOT NULL THEN CASE WHEN is_active = true THEN 0 WHEN is_active = false THEN 2 ELSE 0 END ELSE 0 END as status | CASE WHEN is_active IS NOT NULL THEN CASE WHEN is_active = true THEN 0 WHEN is_active = false THEN 2 ELSE 0 END ELSE 0 END |
| 11 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 13 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 14 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 15 | derived | - | is_system_generated | - | CASE WHEN is_manual IS NOT NULL THEN is_manual ELSE false END as is_system_generated | CASE WHEN is_manual IS NOT NULL THEN is_manual ELSE false END |
| 16 | derived | - | is_vessel_selection_mandatory | - | CASE WHEN on_vessel IS NOT NULL THEN on_vessel ELSE false END as is_vessel_selection_mandatory | CASE WHEN on_vessel IS NOT NULL THEN on_vessel ELSE false END |
| 17 | name | - | tags | - | CASE WHEN legacy_data.name IS NOT NULL AND TRIM(legacy_data.name) <> '' THEN ( SELECT array_agg(DISTINCT tag_value)::text[] FROM ( SELECT LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRI... | CASE WHEN legacy_data.name IS NOT NULL AND TRIM(legacy_data.name) <> '' THEN ( SELECT array_agg(DISTINCT tag_value)::text[] FROM ( SELECT LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRI... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/activity_log_types_migration.sql`

## Validation

- Run `05-validation/master/activity_log_types_validation.sql` if available
- Run `06-rollback/master/activity_log_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
