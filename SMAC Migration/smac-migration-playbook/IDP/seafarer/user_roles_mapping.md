# Table Mapping: "UserRoles" → user_roles

## Overview
- **Legacy Database**: IdentityAdmin_prod
- **Legacy Schema**: public
- **Legacy Table**: "UserRoles"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_roles
- **Source Script**: `04-migration-scripts/idp/seafarer/user_roles_migration.sql`

- **Legacy Path**: `IdentityAdmin_prod.public."UserRoles"`
- **New Path**: `smac_idp_dev.public.user_roles`

## Business Key

- **Composite Key**: (`user_id`, `role_id`)
- **Source (orchestration)**: User Roles - Seafarer (`UserRoles` → `user_roles`)

## Migration Notes

- This migration is for seafarer user-role assignments from IdentityAdmin_prod database.
- Migrates seafarer user-role assignments from IdentityAdmin_prod database. Separate from shore user_roles migration. Uses seafarer subfolder for migration scripts. Requires users and roles (seafarer) to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.user_roles` before insert (full table reload).
- Orchestration dependencies: `users`, `roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_user_id`, `target_id` | `IdentityAdmin_prod.public.Users` → `?.?.users` | - |
| `user_profiles_mapping` | FK lookup | `legacy_user_id`, `user_profile_id`, `target_user_id` | `IdentityAdmin_prod.public.Users` → `?.?.users` | - |
| `roles_id_mapping` | FK lookup | `legacy_role_id`, `target_id` | `IdentityAdmin_prod.public.Roles` → `?.?.roles` | - |

### `users_id_mapping`

- **Output columns**: legacy_user_id, target_id
- **migration.table_mappings**: source_db=IdentityAdmin_prod, source_schema=public, source_table=Users, target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_user_id,
    target_id
FROM migration.table_mappings
WHERE source_db = 'IdentityAdmin_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_table = 'users'
  AND target_db = current_database();
```

### `user_profiles_mapping`

- **Output columns**: legacy_user_id, user_profile_id, target_user_id
- **migration.table_mappings**: source_db=IdentityAdmin_prod, source_schema=public, source_table=Users, target_table=users

```sql
CREATE TEMP TABLE user_profiles_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id::text AS legacy_user_id,
    up.id AS user_profile_id,
    tm.target_id AS target_user_id
FROM migration.table_mappings tm
JOIN public.user_profiles up ON up.user_id = tm.target_id
WHERE tm.source_db = 'IdentityAdmin_prod'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'Users'
  AND tm.target_db = current_database()
  AND tm.target_table = 'users'
ORDER BY tm.source_id, up.created_at;
```

### `roles_id_mapping`

- **Output columns**: legacy_role_id, target_id
- **migration.table_mappings**: source_db=IdentityAdmin_prod, source_schema=public, source_table=Roles, target_table=roles

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_role_id,
    target_id
FROM migration.table_mappings
WHERE source_db = 'IdentityAdmin_prod'
  AND source_schema = 'public'
  AND source_table = 'Roles'
  AND target_table = 'roles'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'IdentityAdmin_prod'::varchar(100), 'public'::varchar(100), 'Roles'::varchar(100), lr.id_text, current_database()::text::varchar(100), 'public'::var... |
| 2 | derived | - | user_type_id | - | (SELECT user_type_id FROM seafarer_user_type LIMIT 1) AS user_type_id | (SELECT user_type_id FROM seafarer_user_type LIMIT 1) |
| 3 | derived | - | name | - | TRIM(lr.name) AS name | TRIM(lr.name) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | derived | - | concurrency_stamp | - | lr.concurrency_stamp | lr.concurrency_stamp |
| 6 | - | - | company_id | - | NULL | NULL::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | - | - | level | - | NULL | NULL::integer |
| 9 | derived | - | code | - | UPPER(REPLACE(REGEXP_REPLACE(TRIM(lr.name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) AS code | UPPER(REPLACE(REGEXP_REPLACE(TRIM(lr.name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) |
| 10 | - | - | superior_role_id | - | NULL | NULL::uuid |
| 11 | derived | - | normalized_name | - | lr.normalized_name | lr.normalized_name |
| 12 | - | - | risk_level | - | NULL | NULL::integer |
| 13 | derived | - | status | - | 0 AS status | 0 |
| 14 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 15 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 16 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 17 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 18 | derived | - | audit_info | - | jsonb_build_object( 'legacy_id', lr.id_text, 'migration_source', 'IdentityAdmin_prod', 'migrated_at', NOW() ) AS audit_info | jsonb_build_object( 'legacy_id', lr.id_text, 'migration_source', 'IdentityAdmin_prod', 'migrated_at', NOW() ) |
| 19 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 20 | - | - | reason_id | - | NULL | NULL::uuid |
| 21 | - | - | remarks | - | NULL | NULL::varchar |
| 22 | derived | - | assign_on_signup | - | false AS assign_on_signup | false |
| 23 | derived | - | is_fdl_role | - | false AS is_fdl_role | false |
| 24 | derived | - | is_system_defined | - | false AS is_system_defined | false |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Users ID Mapping
**Output columns**: `legacy_user_id, target_id`
**migration.table_mappings**: `Users` → `users` (source_db=`IdentityAdmin_prod`)

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_user_id,
    target_id
FROM migration.table_mappings
WHERE source_db = 'IdentityAdmin_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_table = 'users'
  AND target_db = current_database();
```

### 2. User Profiles ID Mapping
**Output columns**: `legacy_user_id, user_profile_id, target_user_id`
**migration.table_mappings**: `Users` → `users` (source_db=`IdentityAdmin_prod`)

```sql
CREATE TEMP TABLE user_profiles_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id::text AS legacy_user_id,
    up.id AS user_profile_id,
    tm.target_id AS target_user_id
FROM migration.table_mappings tm
JOIN public.user_profiles up ON up.user_id = tm.target_id
WHERE tm.source_db = 'IdentityAdmin_prod'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'Users'
  AND tm.target_db = current_database()
  AND tm.target_table = 'users'
ORDER BY tm.source_id, up.created_at;
```

### 3. Roles ID Mapping
**Output columns**: `legacy_role_id, target_id`
**migration.table_mappings**: `Roles` → `roles` (source_db=`IdentityAdmin_prod`)

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_role_id,
    target_id
FROM migration.table_mappings
WHERE source_db = 'IdentityAdmin_prod'
  AND source_schema = 'public'
  AND source_table = 'Roles'
  AND target_table = 'roles'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/seafarer/user_roles_migration.sql`

## Validation

- Run `05-validation/idp/user_roles_validation.sql` if available
- Run `06-rollback/idp/user_roles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
