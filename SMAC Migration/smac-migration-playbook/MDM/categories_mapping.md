# Table Mapping: vessel_categories → categories

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: categories
- **Source Script**: `04-migration-scripts/master/categories_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_categories`
- **New Path**: `smac_master_migration.vessel.categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.categories` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_categories'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(1... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | name | - | level | - | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name))::numeric AS level | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name))::numeric |
| 14 | name, identifier | - | tags | - | generate_meaningful_code() | ARRAY[ generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 15 | name | - | audit_info | - | TRIM(BOTH '_' FROM regexp_replace( regexp_replace( LOWER(TRIM(legacy_data.name)), '[^a-z0-9\s]', '_', 'g' ), '[\s_]+', '_', 'g' )) ] || CASE WHEN TRIM(legacy_data.name) IN ('LPG... | TRIM(BOTH '_' FROM regexp_replace( regexp_replace( LOWER(TRIM(legacy_data.name)), '[^a-z0-9\s]', '_', 'g' ), '[\s_]+', '_', 'g' )) ] || CASE WHEN TRIM(legacy_data.name) IN ('LPG... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/categories_migration.sql`

## Validation

- Run `05-validation/master/categories_validation.sql` if available
- Run `06-rollback/master/categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
