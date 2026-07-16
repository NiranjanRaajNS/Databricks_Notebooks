# Table Mapping: companies → companies

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: companies
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: companies
- **Source Script**: `04-migration-scripts/idp/companies_migration.sql`

- **Legacy Path**: `smac_master_migration.public.companies`
- **New Path**: `smac_idp_dev.public.companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.companies)
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | code | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') AS code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), '') AS name | COALESCE(TRIM(legacy_data.name), '') |
| 4 | description | - | description | - | legacy_data.description AS description | legacy_data.description |
| 5 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 6 | parent_id | - | parent_id | - | legacy_data.parent_id AS parent_id | legacy_data.parent_id |
| 7 | tags | - | tags | - | legacy_data.tags AS tags | legacy_data.tags |
| 8 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |
| 9 | created_at | - | created_at | - | CASE WHEN legacy_data.created_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) END AS created_at | CASE WHEN legacy_data.created_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) END |
| 10 | updated_at, created_at | - | updated_at | - | CASE WHEN legacy_data.updated_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE( legacy_data.updated_at AT TIME ZONE 'UTC', CASE WHEN legacy_dat... | CASE WHEN legacy_data.updated_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE( legacy_data.updated_at AT TIME ZONE 'UTC', CASE WHEN legacy_dat... |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 12 | archived_at | - | archived_at | - | legacy_data.archived_at AS archived_at | legacy_data.archived_at |
| 13 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/companies_migration.sql`

## Validation

- Run `05-validation/idp/companies_validation.sql` if available
- Run `06-rollback/idp/companies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
