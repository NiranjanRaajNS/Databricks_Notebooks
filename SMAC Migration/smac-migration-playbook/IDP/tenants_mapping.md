# Table Mapping: tenants → tenants

## Overview
- **Legacy Database**: smac_base_mdm
- **Legacy Schema**: public
- **Legacy Table**: tenants
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: tenants
- **Source Script**: `04-migration-scripts/idp/tenants_migration.sql`

- **Legacy Path**: `smac_base_mdm.public.tenants`
- **New Path**: `smac_idp_dev.public.tenants`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Tenants (Base MDM) (`tenants` → `tenants`)

## Migration Notes

- Source and target schemas are similar, preserving UUIDs from source
- Migrates tenants from smac_base_mdm. Source and target schemas are similar, preserving UUIDs from source. Maps logos3url to branding_logo_path.

## Special Considerations

- Script performs `TRUNCATE TABLE public.tenants` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'smac_base_mdm'::VARCHAR(100), 'public'::VARCHAR(100), 'tenants'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'publi... |
| 2 | name | - | name | - | CASE WHEN TRIM(COALESCE(legacy_data.name, '')) = '' THEN NULL ELSE TRIM(legacy_data.name) END AS name | CASE WHEN TRIM(COALESCE(legacy_data.name, '')) = '' THEN NULL ELSE TRIM(legacy_data.name) END |
| 3 | code | - | code | - | CASE WHEN TRIM(COALESCE(legacy_data.code, '')) = '' THEN NULL ELSE TRIM(legacy_data.code) END AS code | CASE WHEN TRIM(COALESCE(legacy_data.code, '')) = '' THEN NULL ELSE TRIM(legacy_data.code) END |
| 4 | description | - | description | - | CASE WHEN TRIM(COALESCE(legacy_data.description, '')) = '' THEN NULL ELSE TRIM(legacy_data.description) END AS description | CASE WHEN TRIM(COALESCE(legacy_data.description, '')) = '' THEN NULL ELSE TRIM(legacy_data.description) END |
| 5 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END |
| 6 | archived_at | - | archived_at | - | legacy_data.archived_at | legacy_data.archived_at |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 9 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 10 | audit_info, id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by' IS NOT NULL AND legacy_data.audit_info->>'created_by' <> '' TH... |
| 11 | parent_id | - | parent_id | - | legacy_data.parent_id | legacy_data.parent_id |
| 12 | tags | - | tags | - | legacy_data.tags | legacy_data.tags |
| 13 | workflow_status | - | workflow_status | - | COALESCE(legacy_data.workflow_status, 0) AS workflow_status | COALESCE(legacy_data.workflow_status, 0) |
| 14 | derived | - | template_path | - | NULL AS template_path | NULL |
| 15 | logos3url | - | branding_logo_path | - | CASE WHEN TRIM(COALESCE(legacy_data.logos3url, '')) = '' THEN NULL ELSE TRIM(legacy_data.logos3url) END AS branding_logo_path | CASE WHEN TRIM(COALESCE(legacy_data.logos3url, '')) = '' THEN NULL ELSE TRIM(legacy_data.logos3url) END |
| 16 | derived | - | allowed_domains | - | NULL AS allowed_domains | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/tenants_migration.sql`

## Validation

- Run `05-validation/idp/tenants_validation.sql` if available
- Run `06-rollback/idp/tenants_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
