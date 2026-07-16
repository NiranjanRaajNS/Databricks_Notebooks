# Table Mapping: endpoints → endpoints

## Overview
- **Legacy Database**: smac_base_database
- **Legacy Schema**: public
- **Legacy Table**: endpoints
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: endpoints
- **Source Script**: `04-migration-scripts/idp/endpoints_migration.sql`

- **Legacy Path**: `smac_base_database.public.endpoints`
- **New Path**: `smac_idp_dev.public.endpoints`

## Business Key

- **Composite Key**: (`path`, `method`)
- **Source (orchestration)**: Endpoints (Base Database) (`endpoints` → `endpoints`)

## Migration Notes

- Source and target schemas are identical, preserving UUIDs from source
- Migrates endpoints from smac_base_database. Source and target schemas are identical, preserving UUIDs from source.

## Special Considerations

- Script performs `TRUNCATE TABLE public.endpoints` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'smac_base_database'::VARCHAR(100), 'public'::VARCHAR(100), 'endpoints'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | path | - | path | - | TRIM(legacy_data.path) AS path | TRIM(legacy_data.path) |
| 3 | method | - | method | - | TRIM(legacy_data.method) AS method | TRIM(legacy_data.method) |
| 4 | module_id | - | module_id | - | legacy_data.module_id | legacy_data.module_id |
| 5 | feature_id | - | feature_id | - | legacy_data.feature_id | legacy_data.feature_id |
| 6 | description | - | description | - | CASE WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END AS description | CASE WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END |
| 7 | rate_limit | - | rate_limit | - | legacy_data.rate_limit | legacy_data.rate_limit |
| 8 | action_method | - | action_method | - | TRIM(legacy_data.action_method) AS action_method | TRIM(legacy_data.action_method) |
| 9 | controller | - | controller | - | TRIM(legacy_data.controller) AS controller | TRIM(legacy_data.controller) |
| 10 | authentication_required | - | authentication_required | - | COALESCE(legacy_data.authentication_required, false) AS authentication_required | COALESCE(legacy_data.authentication_required, false) |
| 11 | authorization_required | - | authorization_required | - | COALESCE(legacy_data.authorization_required, false) AS authorization_required | COALESCE(legacy_data.authorization_required, false) |
| 12 | policy_auth_required | - | policy_auth_required | - | COALESCE(legacy_data.policy_auth_required, false) AS policy_auth_required | COALESCE(legacy_data.policy_auth_required, false) |
| 13 | archived_at | - | archived_at | - | legacy_data.archived_at | legacy_data.archived_at |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 18 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 19 | provider | - | provider | - | CASE WHEN TRIM(legacy_data.provider) = '' THEN NULL ELSE TRIM(legacy_data.provider) END AS provider | CASE WHEN TRIM(legacy_data.provider) = '' THEN NULL ELSE TRIM(legacy_data.provider) END |
| 20 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END |
| 21 | parent_id | - | parent_id | - | legacy_data.parent_id | legacy_data.parent_id |
| 22 | tags | - | tags | - | legacy_data.tags | legacy_data.tags |
| 23 | workflow_status | - | workflow_status | - | COALESCE(legacy_data.workflow_status, 0) AS workflow_status | COALESCE(legacy_data.workflow_status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/endpoints_migration.sql`

## Validation

- Run `05-validation/idp/endpoints_validation.sql` if available
- Run `06-rollback/idp/endpoints_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
