# Table Mapping: countries → countries

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: countries
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: countries
- **Source Script**: `04-migration-scripts/idp/countries_migration.sql`

- **Legacy Path**: `smac_master_migration.public.countries`
- **New Path**: `smac_idp_dev.public.countries`

## Business Key

- **Business Key**: `iso_code`
- **Source (orchestration)**: Countries (`countries` → `countries`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.countries)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | code | - | code | - | LEFT(COALESCE(NULLIF(TRIM(legacy_data.code), ''), ''), 10)::VARCHAR(10) AS code | LEFT(COALESCE(NULLIF(TRIM(legacy_data.code), ''), ''), 10)::VARCHAR(10) |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), '') AS name | COALESCE(TRIM(legacy_data.name), '') |
| 4 | iso_code | - | iso_code | - | LEFT(COALESCE(NULLIF(TRIM(legacy_data.iso_code), ''), ''), 10)::VARCHAR(10) AS iso_code | LEFT(COALESCE(NULLIF(TRIM(legacy_data.iso_code), ''), ''), 10)::VARCHAR(10) |
| 5 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 6 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |
| 7 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 8 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 9 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 10 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/countries_migration.sql`

## Validation

- Run `05-validation/idp/countries_validation.sql` if available
- Run `06-rollback/idp/countries_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
