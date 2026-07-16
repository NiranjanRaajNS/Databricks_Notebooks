# Table Mapping: percentage_based_components → percentage_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: percentage_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: percentage_based_components
- **Source Script**: `04-migration-scripts/master/percentage_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.percentage_based_components`
- **New Path**: `smac_master_migration.crewing.percentage_based_components`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Percentage Based Components (`percentage_based_components` → `percentage_based_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates percentage_based_components table. Preserves legacy UUID id when available (source id is uuid, target id is uuid). Columns: proportion (numeric, default 0), derived_component_id (uuid), derived_from_component_id (uuid), isactive (boolean, default false), derived_from_component_type (integer, default 0). Source table doesn't have created_at/updated_at columns - uses NOW(). Legacy id stored in audit_info.

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.percentage_based_components` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'percentage_based_components'::VARCHAR(100), legacy_data.id::text, current_database()::text::... |
| 2 | proportion | - | proportion | - | COALESCE(legacy_data.proportion, 0::numeric) as proportion | COALESCE(legacy_data.proportion, 0::numeric) |
| 3 | derived_component_id | - | derived_component_id | - | legacy_data.derived_component_id as derived_component_id | legacy_data.derived_component_id |
| 4 | derived_ | - | derived_from_component_id | - | legacy_data.derived_ | legacy_data.derived_ |
| 5 | - | - | isactive | - | See source script | See source script |
| 6 | - | - | derived_from_component_type | - | See source script | See source script |
| 7 | - | - | tenant_id | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | defined_by | - | See source script | See source script |
| 10 | - | - | workflow_status | - | See source script | See source script |
| 11 | - | - | status | - | See source script | See source script |
| 12 | - | - | created_at | - | See source script | See source script |
| 13 | - | - | updated_at | - | See source script | See source script |
| 14 | - | - | audit_info | - | See source script | See source script |
| 15 | - | - | level | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/percentage_based_components_migration.sql`

## Validation

- Run `05-validation/master/percentage_based_components_validation.sql` if available
- Run `06-rollback/master/percentage_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
