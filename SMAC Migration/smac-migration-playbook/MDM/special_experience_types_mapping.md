# Table Mapping: special_experience_type → special_experience_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: special_experience_type
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: special_experience_types
- **Source Script**: `04-migration-scripts/master/special_experience_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.special_experience_type`
- **New Path**: `smac_master_migration.crewing.special_experience_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Special Experience Type (`special_experience_type` → `special_experience_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates special_experience_type preserving legacy UUID from id column. Generates code from name using UPPER(REGEXP_REPLACE(TRIM(name), '[^A-Za-z0-9]', '_', 'g')). Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.special_experience_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'special_experience_type'::VARCHAR(100), legacy_data.id::text, current_database()::text::V... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), gen_random_uuid()::text) |
| 3 | name | - | name | - | TRIM(legacy_data.name) AS name | TRIM(legacy_data.name) |
| 4 | derived | - | description | - | NULL AS description | NULL |
| 5 | derived | - | level | - | 0 AS level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 11 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 12 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | derived | - | tags | - | NULL AS tags | NULL |
| 15 | derived | - | status | - | 0 AS status | 0 |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/special_experience_types_migration.sql`

## Validation

- Run `05-validation/master/special_experience_types_validation.sql` if available
- Run `06-rollback/master/special_experience_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
