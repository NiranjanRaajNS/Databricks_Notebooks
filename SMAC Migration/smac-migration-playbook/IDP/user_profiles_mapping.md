# Table Mapping: "UserProfiles" → user_profiles

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "UserProfiles"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_profiles
- **Source Script**: `04-migration-scripts/idp/user_profiles_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."UserProfiles"`
- **New Path**: `smac_idp_dev.public.user_profiles`

## Business Key

- **Business Key**: `user_id`
- **Source (orchestration)**: User Profiles - Seafarer (`UserProfiles` → `user_profiles`)

## Migration Notes

- Migrates seafarer user profile information from IdentityAdmin_prod database. Separate from shore user_profiles migration. Uses seafarer subfolder for migration scripts. Requires users (seafarer) to be migrated first.

## Special Considerations

- Orchestration dependencies: `users`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `departments_id_mapping` | DELETE FROM public.user_profiles;  -- Commented out: | `legacy_id`, `target_id::uuid` | `migration.table_mappings` (see SQL) | - |
| `companies_id_mapping` | FK lookup | `legacy_id`, `target_id::uuid` | `migration.table_mappings` (see SQL) | - |

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

### `departments_id_mapping`

- **Purpose**: DELETE FROM public.user_profiles;  -- Commented out:
- **Output columns**: legacy_id, target_id::uuid
- **migration.table_mappings**: target_table=departments

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::integer as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

### `companies_id_mapping`

- **Output columns**: legacy_id, target_id::uuid
- **migration.table_mappings**: target_table=companies

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    source_id::integer as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | user_id | - | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as user_id | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | firstname | - | first_name | - | TRIM(legacy_data.firstname) as first_name | TRIM(legacy_data.firstname) |
| 4 | lastname | - | last_name | - | TRIM(legacy_data.lastname) as last_name | TRIM(legacy_data.lastname) |
| 5 | emailid | - | email | - | TRIM(legacy_data.emailid) as email | TRIM(legacy_data.emailid) |
| 6 | mobile | - | phone_number | - | TRIM(legacy_data.mobile) as phone_number | TRIM(legacy_data.mobile) |
| 7 | userphoto | - | profile_picture | - | TRIM(legacy_data.userphoto) as profile_picture | TRIM(legacy_data.userphoto) |
| 8 | derived | - | department_id | - | dept_map.target_id as department_id | dept_map.target_id |
| 9 | derived | - | company_id | - | comp_map.target_id as company_id | comp_map.target_id |
| 10 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 12 | id, userid | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'legacy_userid', legacy_data.userid::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) as au... | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'legacy_userid', legacy_data.userid::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) |

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

### 2. Departments ID Mapping
**Purpose**: DELETE FROM public.user_profiles;  -- Commented out:
**Output columns**: `legacy_id, target_id::uuid`
**migration.table_mappings**: `target_table='departments'`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::integer as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

### 3. Companies ID Mapping
**Output columns**: `legacy_id, target_id::uuid`
**migration.table_mappings**: `target_table='companies'`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    source_id::integer as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/user_profiles_migration.sql`

## Validation

- Run `05-validation/idp/user_profiles_validation.sql` if available
- Run `06-rollback/idp/user_profiles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
