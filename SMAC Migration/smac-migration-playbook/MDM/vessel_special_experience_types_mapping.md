# Table Mapping: special_experience_type → vessel_special_experience_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: special_experience_type
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: vessel_special_experience_types
- **Source Script**: `04-migration-scripts/master/vessel_special_experience_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.special_experience_type`
- **New Path**: `smac_master_migration.crewing.vessel_special_experience_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Special Experience Types (`special_experience_type` → `vessel_special_experience_types`)

## Migration Notes

- Preserve legacy id (UUID) as id if available
- Record legacy id (uuid) → new uuid (preserved) in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates special_experience_type to vessel_special_experience_types. Preserves legacy UUID from id column. Generates code from name. Extracts audit_info from legacy audit_info JSONB. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.vessel_special_experience_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'special_experience_type'::VARCHAR(100), legacy_data.id::text, current_database()::text::V... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | LEFT(COALESCE(TRIM(legacy_data.name), 'UNKNOWN'), 255) as name | LEFT(COALESCE(TRIM(legacy_data.name), 'UNKNOWN'), 255) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | derived | - | status | - | 0 as status | 0 |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 15 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_special_experience_types_migration.sql`

## Validation

- Run `05-validation/master/vessel_special_experience_types_validation.sql` if available
- Run `06-rollback/master/vessel_special_experience_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
