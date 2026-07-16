# Table Mapping: engine_make → engine_makes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: engine_make
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: engine_makes
- **Source Script**: `04-migration-scripts/master/engine_makes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.engine_make`
- **New Path**: `smac_master_migration.vessel.engine_makes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Engine Make (`engine_make` → `engine_makes`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.engine_makes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'engine_make'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), '... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(COALESCE(legacy_data.name, 'UNKNOWN'), legacy_data.identifier::text) |
| 3 | name | - | name | - | COALESCE(legacy_data.name, 'UNKNOWN') AS name | COALESCE(legacy_data.name, 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' OR TRIM(COALESCE(legacy_... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' OR TRIM(COALESCE(legacy_... |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 12 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/engine_makes_migration.sql`

## Validation

- Run `05-validation/master/engine_makes_validation.sql` if available
- Run `06-rollback/master/engine_makes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
