# Table Mapping: uom → storage_units

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: uom
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: storage_units
- **Source Script**: `04-migration-scripts/master/storage_units_migration.sql`

- **Legacy Path**: `synergy_master.enum.uom`
- **New Path**: `smac_master_migration.vessel.storage_units`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Uom (`uom` → `storage_units`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates enum.uom preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.storage_units` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'uom'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'vessel'::V... |
| 2 | code | - | code | - | TRIM(legacy_data.code) as code | TRIM(legacy_data.code) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 12 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/storage_units_migration.sql`

## Validation

- Run `05-validation/master/storage_units_validation.sql` if available
- Run `06-rollback/master/storage_units_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
