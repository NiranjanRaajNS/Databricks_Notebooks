# Table Mapping: "UserRoles" → user_roles

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "UserRoles"
- **New Database**: smac_idp_dev_int
- **New Schema**: public
- **New Table**: user_roles
- **Source Script**: `04-migration-scripts/idp/user_roles_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."UserRoles"`
- **New Path**: `smac_idp_dev_int.public.user_roles`

## Business Key

- **Composite Key**: (`user_id`, `role_id`)
- **Source (orchestration)**: User Roles - Seafarer (`UserRoles` → `user_roles`)

## Migration Notes

- Source has composite PK (UserId, RoleId), target has single uuid PK
- Migrates seafarer user-role assignments from IdentityAdmin_prod database. Separate from shore user_roles migration. Uses seafarer subfolder for migration scripts. Requires users and roles (seafarer) to be migrated first.

## Special Considerations

- Orchestration dependencies: `users`, `roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `roles_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `users_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

### `roles_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=roles

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'roles'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | user_id | - | COALESCE(u_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as user_id | COALESCE(u_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | role_id | - | COALESCE(r_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as role_id | COALESCE(r_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | assigned_by | - | NULL as assigned_by | NULL |
| 5 | derived | - | role_code | - | NULL as role_code | NULL |
| 6 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 7 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 8 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 9 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 10 | user_id_text, role_id_text | - | audit_info | - | jsonb_build_object( 'legacy_user_id', legacy_data.user_id_text, 'legacy_role_id', legacy_data.role_id_text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_pro... | jsonb_build_object( 'legacy_user_id', legacy_data.user_id_text, 'legacy_role_id', legacy_data.role_id_text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_pro... |
| 11 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 12 | derived | - | status | - | 0 as status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Users ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='users'`

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

### 2. Roles ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='roles'`

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'roles'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/user_roles_migration.sql`

## Validation

- Run `05-validation/idp/user_roles_validation.sql` if available
- Run `06-rollback/idp/user_roles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
