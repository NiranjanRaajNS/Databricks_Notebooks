# Table Mapping: vessels → vessels

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: vessel
- **Legacy Table**: vessels
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: vessels
- **Source Script**: `04-migration-scripts/idp/vessels_migration.sql`

- **Legacy Path**: `smac_master_migration.vessel.vessels`
- **New Path**: `smac_idp_dev.public.vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.vessel.vessels)
- Mappings are stored in smac_master_migration.migration.table_mappings, not local database

## Special Considerations

- Mappings are stored in and read from smac_master_migration.migration.table_mappings
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | vessel_code | - | code | - | CAST(LEFT(TRIM(COALESCE(legacy_data.vessel_code, '')), 20) AS VARCHAR(20)) AS code | CAST(LEFT(TRIM(COALESCE(legacy_data.vessel_code, '')), 20) AS VARCHAR(20)) |
| 3 | name | - | name | - | CAST(LEFT(TRIM(COALESCE(legacy_data.name, '')), 20) AS VARCHAR(20)) AS name | CAST(LEFT(TRIM(COALESCE(legacy_data.name, '')), 20) AS VARCHAR(20)) |
| 4 | imo_number | - | imo_number | - | COALESCE(TRIM(legacy_data.imo_number::text), '') AS imo_number | COALESCE(TRIM(legacy_data.imo_number::text), '') |
| 5 | category_id | - | category_id | - | legacy_data.category_id AS category_id | legacy_data.category_id |
| 6 | sub_category_id | - | sub_category_id | - | legacy_data.sub_category_id AS sub_category_id | legacy_data.sub_category_id |
| 7 | derived | - | official_number | - | NULL AS official_number | NULL |
| 8 | class_no | - | class_no | - | legacy_data.class_no AS class_no | legacy_data.class_no |
| 9 | derived | - | vdr_make_id | - | NULL AS vdr_make_id | NULL |
| 10 | ship_builder_id | - | ship_builder_id | - | legacy_data.ship_builder_id AS ship_builder_id | legacy_data.ship_builder_id |
| 11 | yard_country_id | - | yard_country_id | - | legacy_data.yard_country_id AS yard_country_id | legacy_data.yard_country_id |
| 12 | built_year | - | built_year | - | legacy_data.built_year AS built_year | legacy_data.built_year |
| 13 | build_on | - | build_on | - | legacy_data.build_on AS build_on | legacy_data.build_on |
| 14 | keel_laid | - | keel_laid | - | legacy_data.keel_laid AS keel_laid | legacy_data.keel_laid |
| 15 | launched | - | launched | - | legacy_data.launched AS launched | legacy_data.launched |
| 16 | delivered | - | delivered | - | legacy_data.delivered AS delivered | legacy_data.delivered |
| 17 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 18 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 19 | version | - | version | - | COALESCE(legacy_data.version, 1) AS version | COALESCE(legacy_data.version, 1) |
| 20 | derived | - | defined_by | - | NULL AS defined_by | NULL |
| 21 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 22 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 23 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 24 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 25 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 26 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |
| 27 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/vessels_migration.sql`

## Validation

- Run `05-validation/idp/vessels_validation.sql` if available
- Run `06-rollback/idp/vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
