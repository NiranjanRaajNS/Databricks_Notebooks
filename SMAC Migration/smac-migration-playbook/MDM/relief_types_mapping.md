# Table Mapping: reliefType → relief_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: reliefType
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: relief_types
- **Source Script**: `04-migration-scripts/master/relief_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.reliefType`
- **New Path**: `smac_master_migration.crewing.relief_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Relief Types (`reliefType` → `relief_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates relief_types from enum.reliefType preserving identifier UUID

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.relief_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'reliefType'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'cre... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | name | - | description | - | TRIM(legacy_data.name) as description | TRIM(legacy_data.name) |
| 5 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 12 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 13 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 14 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 15 | name | - | tags | - | generate_meaningful_code() | CASE WHEN generate_meaningful_code(TRIM(legacy_data.name), NULL) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/relief_types_migration.sql`

## Validation

- Run `05-validation/master/relief_types_validation.sql` if available
- Run `06-rollback/master/relief_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
