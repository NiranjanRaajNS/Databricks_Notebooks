# Table Mapping: vessel_classes → classes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_classes
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: classes
- **Source Script**: `04-migration-scripts/master/classes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_classes`
- **New Path**: `smac_master_migration.vessel.classes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Classes (`vessel_classes` → `classes`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_classes preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.classes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_classes'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(LEFT(COALESCE(legacy_data.name, 'UNKNOWN'), 255), legacy_data.identifier::text) |
| 3 | name | - | name | - | LEFT(COALESCE(legacy_data.name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(legacy_data.name, 'UNKNOWN'), 255) |
| 4 | derived | - | description | - | NULL AS description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 14 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/classes_migration.sql`

## Validation

- Run `05-validation/master/classes_validation.sql` if available
- Run `06-rollback/master/classes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
