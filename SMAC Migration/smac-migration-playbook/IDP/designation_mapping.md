# Table Mapping: designations → designations

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: designations
- **New Database**: smac_master_migration
- **New Schema**: current DB public
- **New Table**: designations
- **Source Script**: `04-migration-scripts/idp/designation_migration.sql`

- **Legacy Path**: `smac_master_migration.public.designations`
- **New Path**: `current DB public.designations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Designations (`designations` → `designations`)

## Migration Notes

- Copies public.designations from smac_master_migration into IDP. department_id is UUID (migrate departments first). Enable when target uses public.designations.

## Special Considerations

- Script performs `TRUNCATE TABLE public.designations` before insert (full table reload).
- Orchestration dependencies: `departments`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | src.id | src.id |
| 2 | code | - | code | - | TRIM(src.code) AS code | TRIM(src.code) |
| 3 | name | - | name | - | TRIM(src.name) AS name | TRIM(src.name) |
| 4 | description | - | description | - | src.description | src.description |
| 5 | department_id | - | department_id | - | src.department_id | src.department_id |
| 6 | tenant_id | - | tenant_id | - | src.tenant_id | src.tenant_id |
| 7 | parent_id | - | parent_id | - | src.parent_id | src.parent_id |
| 8 | level | - | level | - | src.level | src.level |
| 9 | version | - | version | - | src.version | src.version |
| 10 | defined_by | - | defined_by | - | src.defined_by | src.defined_by |
| 11 | workflow_status | - | workflow_status | - | src.workflow_status | src.workflow_status |
| 12 | status | - | status | - | src.status | src.status |
| 13 | created_at | - | created_at | - | src.created_at | src.created_at |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(src.updated_at, src.created_at, NOW()) AS updated_at | COALESCE(src.updated_at, src.created_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | src.deleted_at | src.deleted_at |
| 16 | archived_at | - | archived_at | - | src.archived_at | src.archived_at |
| 17 | audit_info | - | audit_info | - | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.designations' ) AS audit_info | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.designations' ) |
| 18 | tags | - | tags | - | src.tags | src.tags |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/designation_migration.sql`

## Validation

- Run `05-validation/idp/designation_validation.sql` if available
- Run `06-rollback/idp/designation_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
