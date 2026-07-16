# Table Mapping: company_services → company_service_mapping

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: company_services
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: company_service_mapping
- **Source Script**: `04-migration-scripts/idp/company_service_mapping_migration.sql`

- **Legacy Path**: `smac_master_migration.public.company_services`
- **New Path**: `smac_idp_dev.public.company_service_mapping`

## Business Key

- **Composite Key**: (`CompanyId`, `ServiceTypeId`)
- **Source (orchestration)**: Company Service Mapping (`CompanyServiceMapping` → `company_service_mapping`)

## Migration Notes

- Reading from already-migrated master database (same pattern as companies_migration.sql).

## Special Considerations

- Orchestration dependencies: `companies`, `service_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | company_id | - | company_id | - | legacy_data.company_id | legacy_data.company_id |
| 3 | service_type_id | - | service_type_id | - | legacy_data.service_type_id | legacy_data.service_type_id |
| 4 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 5 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |
| 6 | created_at | - | created_at | - | CASE WHEN legacy_data.created_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) END AS created_at | CASE WHEN legacy_data.created_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) END |
| 7 | updated_at, created_at | - | updated_at | - | CASE WHEN legacy_data.updated_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE( legacy_data.updated_at AT TIME ZONE 'UTC', CASE WHEN legacy_dat... | CASE WHEN legacy_data.updated_at IN ('-infinity'::timestamptz, 'infinity'::timestamptz) THEN NOW() ELSE COALESCE( legacy_data.updated_at AT TIME ZONE 'UTC', CASE WHEN legacy_dat... |
| 8 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) || jsonb_build_object( 'migration_source', 'smac_master_migration.public.company_services', 'migrated_at', NOW() ) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) || jsonb_build_object( 'migration_source', 'smac_master_migration.public.company_services', 'migrated_at', NOW() ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/company_service_mapping_migration.sql`

## Validation

- Run `05-validation/idp/company_service_mapping_validation.sql` if available
- Run `06-rollback/idp/company_service_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
