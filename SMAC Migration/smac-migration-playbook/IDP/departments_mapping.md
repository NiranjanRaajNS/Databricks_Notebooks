# Table Mapping: departments → departments

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: departments
- **New Database**: smac_master_migration
- **New Schema**: current DB public
- **New Table**: departments
- **Source Script**: `04-migration-scripts/idp/departments_migration.sql`

- **Legacy Path**: `smac_master_migration.public.departments`
- **New Path**: `current DB public.departments`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- TRUNCATE public.departments then copy from smac_master_migration.public.departments (dblink). Clears migration.table_mappings for departments/Department. Preserves UUIDs for FK alignment with designations from master.

## Special Considerations

- Script truncates target table(s) before insert (full reload): `public.departments`, `public.designations`.

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | src.id | src.id |
| 2 | name | - | name | - | TRIM(src.name) AS name | TRIM(src.name) |
| 3 | code, name | - | code | - | generate_meaningful_code() | COALESCE( NULLIF(TRIM(src.code), ''), generate_meaningful_code(UPPER(TRIM(src.name)), NULL) ) |
| 4 | derived | - | company_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS company_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 5 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(src.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 6 | status | - | status | - | COALESCE(src.status, 0) AS status | COALESCE(src.status, 0) |
| 7 | created_at | - | created_at | - | COALESCE(src.created_at, NOW()) AS created_at | COALESCE(src.created_at, NOW()) |
| 8 | updated_at, created_at | - | updated_at | - | COALESCE(src.updated_at, src.created_at, NOW()) AS updated_at | COALESCE(src.updated_at, src.created_at, NOW()) |
| 9 | deleted_at | - | deleted_at | - | src.deleted_at | src.deleted_at |
| 10 | audit_info | - | audit_info | - | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.departments' ) AS audit_info | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.departments' ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/departments_migration.sql`

## Validation

- Run `05-validation/idp/departments_validation.sql` if available
- Run `06-rollback/idp/departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
