# Table Mapping: functionalities → modules

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: functionalities
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: modules
- **Source Script**: `04-migration-scripts/idp/modules_migration.sql`

- **Legacy Path**: `synergy_master.public.functionalities`
- **New Path**: `smac_idp_dev.public.modules`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Modules (`functionalities` → `modules`)

## Migration Notes

- IDP version includes module_category_id, mfe_code, mfe_url

## Special Considerations

- Orchestration dependencies: `module_categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `module_categories_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `module_categories_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=module_categories

```sql
CREATE TEMP TABLE module_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'module_categories'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | app_name | - | id | - | DISTINCT ON (TRIM(UPPER(legacy_data.app_name))) gen_random_uuid() as id | DISTINCT ON (TRIM(UPPER(legacy_data.app_name))) gen_random_uuid() |
| 2 | app_name | - | name | - | TRIM(legacy_data.app_name) as name | TRIM(legacy_data.app_name) |
| 3 | derived | - | description | - | NULL as description | NULL |
| 4 | derived | - | level | - | 0 as level | 0 |
| 5 | app_name | - | code | - | UPPER(REGEXP_REPLACE(TRIM(legacy_data.app_name), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(legacy_data.app_name), '[^A-Za-z0-9]', '_', 'g')) |
| 6 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) as created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 8 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) as updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 9 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 10 | id, app_name | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id, 'legacy_app_name', legacy_data.app_name, 'migrated_at', NOW(), 'migration_source', 'synergy_master.public.functionalities' ) as ... | jsonb_build_object( 'legacy_id', legacy_data.id, 'legacy_app_name', legacy_data.app_name, 'migrated_at', NOW(), 'migration_source', 'synergy_master.public.functionalities' ) |
| 11 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 12 | derived | - | is_display_required | - | true as is_display_required | true |
| 13 | derived | - | module_category_id | - | mc_map.target_id as module_category_id | mc_map.target_id |
| 14 | derived | - | mfe_code | - | NULL as mfe_code | NULL |
| 15 | derived | - | mfe_url | - | NULL as mfe_url | NULL |
| 16 | derived | - | status | - | 0 as status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Module Categories ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='module_categories'`

```sql
CREATE TEMP TABLE module_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'module_categories'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/modules_migration.sql`

## Validation

- Run `05-validation/idp/modules_validation.sql` if available
- Run `06-rollback/idp/modules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
