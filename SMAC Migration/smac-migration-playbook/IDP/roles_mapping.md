# Table Mapping: "Roles" → roles

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Roles"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: roles
- **Source Script**: `04-migration-scripts/idp/roles_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Roles"`
- **New Path**: `smac_idp_dev.public.roles`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Roles (Seafarer) (`Roles` → `roles`)

## Migration Notes

- SAC table only has 4 columns: "Id", "Name", "NormalizedName", "ConcurrencyStamp"
- Migrates seafarer roles from IdentityAdmin_prod database. Separate from shore roles migration. Uses seafarer subfolder for migration scripts.

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id_text | - | id | - | CASE WHEN legacy_data.id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.id_text::uuid ELSE gen_random_uuid() END as id | CASE WHEN legacy_data.id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.id_text::uuid ELSE gen_random_uuid() END |
| 2 | derived | - | user_type_id | - | NULL as user_type_id | NULL |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | concurrency_stamp | - | concurrency_stamp | - | legacy_data.concurrency_stamp | legacy_data.concurrency_stamp |
| 6 | derived | - | company_id | - | NULL as company_id | NULL |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | level | - | NULL as level | NULL |
| 9 | name | - | code | - | UPPER(REPLACE(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) as code | UPPER(REPLACE(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) |
| 10 | derived | - | superior_role_id | - | NULL as superior_role_id | NULL |
| 11 | normalized_name | - | normalized_name | - | legacy_data.normalized_name | legacy_data.normalized_name |
| 12 | derived | - | risk_level | - | NULL as risk_level | NULL |
| 13 | derived | - | status | - | 0 as status | 0 |
| 14 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 15 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 16 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 17 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 18 | id_text | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id_text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) as audit_info | jsonb_build_object( 'legacy_id', legacy_data.id_text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) |
| 19 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 20 | derived | - | reason_id | - | NULL as reason_id | NULL |
| 21 | derived | - | remarks | - | NULL as remarks | NULL |
| 22 | derived | - | assign_on_signup | - | false as assign_on_signup | false |
| 23 | derived | - | is_fdl_role | - | false as is_fdl_role | false |
| 24 | derived | - | is_system_defined | - | true as is_system_defined | true |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/roles_migration.sql`

## Validation

- Run `05-validation/idp/roles_validation.sql` if available
- Run `06-rollback/idp/roles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
