# Table Mapping: users_roles_seafarer_patch → users_roles_seafarer_patch

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: users_roles_seafarer_patch
- **Source Script**: `04-migration-scripts/idp/users_roles_seafarer_patch_migration.sql`


## Business Key

- **Business Key**: `r.user_type_id`
- **Source (orchestration)**: Seafarer Role Patch (`UserRoles` → `user_roles`)

## Migration Notes

- Patch: assign Seafarer role to user_profiles whose user_type is tagged seafarer (all profiles, not only default). Target DB only (no dblink). Requires roles seed with Seafarer role per seafarer user_type.

## Special Considerations

- Orchestration dependencies: `roles`, `users`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() AS id | gen_random_uuid() |
| 2 | derived | - | user_id | - | up.id AS user_id | up.id |
| 3 | derived | - | role_id | - | sr.role_id | sr.role_id |
| 4 | - | - | assigned_by | - | NULL | NULL::uuid |
| 5 | derived | - | role_code | - | sr.role_code | sr.role_code |
| 6 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 7 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 8 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 9 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 10 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) ||... |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | derived | - | status | - | STATUS_ACTIVE | :'STATUS_ACTIVE'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/users_roles_seafarer_patch_migration.sql`

## Validation

- Run `05-validation/idp/users_roles_seafarer_patch_validation.sql` if available
- Run `06-rollback/idp/users_roles_seafarer_patch_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
