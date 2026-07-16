# Table Mapping: categories → vessel_types

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: vessel
- **Legacy Table**: categories
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: vessel_types
- **Source Script**: `04-migration-scripts/idp/vessel_types_migration.sql`

- **Legacy Path**: `smac_master_migration.vessel.categories`
- **New Path**: `smac_idp_dev.public.vessel_types`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Vessel Types (`categories` → `vessel_types`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.vessel.categories)
- Mappings are stored in smac_master_migration.migration.table_mappings, not local database

## Special Considerations

- Mappings are stored in and read from smac_master_migration.migration.table_mappings

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id as id | legacy_data.id |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | code, name | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), UPPER(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g'))) as code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), UPPER(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g'))) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | derived | - | is_capacity_grain | - | false as is_capacity_grain | false |
| 6 | derived | - | is_capacity_bale | - | false as is_capacity_bale | false |
| 7 | derived | - | is_capacity_liquid | - | false as is_capacity_liquid | false |
| 8 | derived | - | is_capacity_gas | - | false as is_capacity_gas | false |
| 9 | derived | - | is_capacity_teu | - | false as is_capacity_teu | false |
| 10 | derived | - | is_capacity_fuel_oil | - | false as is_capacity_fuel_oil | false |
| 11 | derived | - | is_capacity_ceu | - | false as is_capacity_ceu | false |
| 12 | derived | - | is_capacity_ballast | - | false as is_capacity_ballast | false |
| 13 | derived | - | uom_id | - | NULL as uom_id | NULL |
| 14 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 15 | version | - | version | - | COALESCE(legacy_data.version, 1) as version | COALESCE(legacy_data.version, 1) |
| 16 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 17 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 18 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 19 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 20 | id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, legacy_data.id:... |
| 21 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 22 | status | - | status | - | COALESCE(legacy_data.status, 0) as status | COALESCE(legacy_data.status, 0) |
| 23 | derived | - | workflow_status | - | 0 as workflow_status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/vessel_types_migration.sql`

## Validation

- Run `05-validation/idp/vessel_types_validation.sql` if available
- Run `06-rollback/idp/vessel_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
