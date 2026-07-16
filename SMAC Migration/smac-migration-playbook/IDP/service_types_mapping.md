# Table Mapping: service_types → service_type

## Overview
- **Legacy Database**: smac_base_mdm
- **Legacy Schema**: public
- **Legacy Table**: service_types
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: service_type
- **Source Script**: `04-migration-scripts/idp/service_types_migration.sql`

- **Legacy Path**: `smac_base_mdm.public.service_types`
- **New Path**: `smac_idp_dev.public.service_type`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `service_types`)

## Migration Notes

- Source and target schemas are similar, preserving UUIDs from source
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Special Considerations

- Script performs `TRUNCATE TABLE public.service_type` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'smac_base_mdm'::VARCHAR(100), 'public'::VARCHAR(100), 'service_types'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), ... |
| 2 | code | - | code | - | CASE WHEN TRIM(COALESCE(legacy_data.code, '')) = '' THEN NULL ELSE TRIM(legacy_data.code) END AS code | CASE WHEN TRIM(COALESCE(legacy_data.code, '')) = '' THEN NULL ELSE TRIM(legacy_data.code) END |
| 3 | name | - | name | - | CASE WHEN TRIM(COALESCE(legacy_data.name, '')) = '' THEN NULL ELSE TRIM(legacy_data.name) END AS name | CASE WHEN TRIM(COALESCE(legacy_data.name, '')) = '' THEN NULL ELSE TRIM(legacy_data.name) END |
| 4 | description | - | description | - | CASE WHEN TRIM(COALESCE(legacy_data.description, '')) = '' THEN NULL ELSE TRIM(legacy_data.description) END AS description | CASE WHEN TRIM(COALESCE(legacy_data.description, '')) = '' THEN NULL ELSE TRIM(legacy_data.description) END |
| 5 | req_in_vessel_creation | - | req_in_vessel_creation | - | COALESCE(legacy_data.req_in_vessel_creation, false) AS req_in_vessel_creation | COALESCE(legacy_data.req_in_vessel_creation, false) |
| 6 | max_company_count | - | max_company_count | - | COALESCE(legacy_data.max_company_count, 0) AS max_company_count | COALESCE(legacy_data.max_company_count, 0) |
| 7 | tags | - | tags | - | legacy_data.tags | legacy_data.tags |
| 8 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END |
| 9 | archived_at | - | archived_at | - | legacy_data.archived_at | legacy_data.archived_at |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 13 | audit_info, id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by' IS NOT NULL AND legacy_data.audit_info->>'created_by' <> '' TH... |
| 14 | tenant_id | - | tenant_id | - | legacy_data.tenant_id | legacy_data.tenant_id |
| 15 | parent_id | - | parent_id | - | legacy_data.parent_id | legacy_data.parent_id |
| 16 | workflow_status | - | workflow_status | - | COALESCE(legacy_data.workflow_status, 0) AS workflow_status | COALESCE(legacy_data.workflow_status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/service_types_migration.sql`

## Validation

- Run `05-validation/idp/service_types_validation.sql` if available
- Run `06-rollback/idp/service_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
