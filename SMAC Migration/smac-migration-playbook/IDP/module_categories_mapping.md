# Table Mapping: module_categories → module_categories

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: module_categories
- **Source Script**: `04-migration-scripts/idp/module_categories_migration.sql`

- **Legacy Path**: `synergy_master.public.functionalities.app_name`
- **New Path**: `smac_idp_dev.public.module_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- Extracts distinct app_name values from functionalities table

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | app_name | - | id | - | DISTINCT ON (TRIM(UPPER(legacy_data.app_name))) gen_random_uuid() as id | DISTINCT ON (TRIM(UPPER(legacy_data.app_name))) gen_random_uuid() |
| 2 | app_name | - | name | - | TRIM(legacy_data.app_name) as name | TRIM(legacy_data.app_name) |
| 3 | derived | - | description | - | NULL as description | NULL |
| 4 | derived | - | level | - | 0 as level | 0 |
| 5 | app_name | - | code | - | UPPER(REGEXP_REPLACE(TRIM(legacy_data.app_name), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(legacy_data.app_name), '[^A-Za-z0-9]', '_', 'g')) |
| 6 | derived | - | is_display_required | - | true as is_display_required | true |
| 7 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 8 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 9 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 10 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 11 | app_name | - | audit_info | - | jsonb_build_object( 'legacy_app_name', legacy_data.app_name, 'migrated_at', NOW(), 'migration_source', 'synergy_master.public.functionalities' ) as audit_info | jsonb_build_object( 'legacy_app_name', legacy_data.app_name, 'migrated_at', NOW(), 'migration_source', 'synergy_master.public.functionalities' ) |
| 12 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 13 | derived | - | status | - | 0 as status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/module_categories_migration.sql`

## Validation

- Run `05-validation/idp/module_categories_validation.sql` if available
- Run `06-rollback/idp/module_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
