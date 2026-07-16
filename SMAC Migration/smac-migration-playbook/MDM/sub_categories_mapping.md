# Table Mapping: vessel_sub_categories → sub_categories

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_sub_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: sub_categories
- **Source Script**: `04-migration-scripts/master/sub_categories_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_sub_categories`
- **New Path**: `smac_master_migration.vessel.sub_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Sub Categories (`vessel_sub_categories` → `sub_categories`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_sub_categories preserving identifier UUID as id if available. Target schema is vessel

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.sub_categories` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_sub_categories'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCH... |
| 2 | derived | - | category_id | - | vc.identifier as category_id | vc.identifier |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 5 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NOT NULL AND TRIM(legacy_data.status) != '' THEN CASE WHEN LOWER(TRIM(legacy_data.status)) IN ('ac... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NOT NULL AND TRIM(legacy_data.status) != '' THEN CASE WHEN LOWER(TRIM(legacy_data.status)) IN ('ac... |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 15 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/sub_categories_migration.sql`

## Validation

- Run `05-validation/master/sub_categories_validation.sql` if available
- Run `06-rollback/master/sub_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
