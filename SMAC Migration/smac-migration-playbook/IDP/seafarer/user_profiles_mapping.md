# Table Mapping: "Users" → user_profiles

## Overview
- **Legacy Database**: IdentityAdmin_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_profiles
- **Source Script**: `04-migration-scripts/idp/seafarer/user_profiles_migration.sql`

- **Legacy Path**: `IdentityAdmin_prod.public."Users"`
- **New Path**: `smac_idp_dev.public.user_profiles`

## Business Key

- **Business Key**: `user_id`
- **Source (orchestration)**: User Profiles - Seafarer (`UserProfiles` → `user_profiles`)

## Migration Notes

- This migration extracts user profile information from Users table in IdentityAdmin_prod database.
- Migrates seafarer user profile information from IdentityAdmin_prod database. Separate from shore user_profiles migration. Uses seafarer subfolder for migration scripts. Requires users (seafarer) to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.user_profiles` before insert (full table reload).
- Orchestration dependencies: `users`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id_text | - | id | - | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Users'::VARCHAR(100), legacy_data.id_text || '|PROFILE', current_database()::text::VAR... | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Users'::VARCHAR(100), legacy_data.id_text || '|PROFILE', current_database()::text::VAR... |
| 2 | derived | - | user_id | - | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as user_id | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | user_type | - | '00000000-0000-0000-0000-000000000000'::uuid as user_type | '00000000-0000-0000-0000-000000000000'::uuid |
| 4 | derived | - | is_default_profile | - | false as is_default_profile | false |
| 5 | derived | - | lock_out_enabled | - | false as lock_out_enabled | false |
| 6 | first_name | - | first_name | - | TRIM(COALESCE(legacy_data.first_name, '')) as first_name | TRIM(COALESCE(legacy_data.first_name, '')) |
| 7 | last_name | - | last_name | - | TRIM(COALESCE(legacy_data.last_name, '')) as last_name | TRIM(COALESCE(legacy_data.last_name, '')) |
| 8 | email | - | email | - | TRIM(COALESCE(legacy_data.email, '')) as email | TRIM(COALESCE(legacy_data.email, '')) |
| 9 | phone_number | - | phone_number | - | TRIM(COALESCE(legacy_data.phone_number, '')) as phone_number | TRIM(COALESCE(legacy_data.phone_number, '')) |
| 10 | derived | - | profile_picture | - | NULL as profile_picture | NULL |
| 11 | derived | - | department_id | - | NULL as department_id | NULL |
| 12 | derived | - | company_id | - | NULL as company_id | NULL |
| 13 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | modified_at | - | updated_at | - | COALESCE(legacy_data.modified_at, NOW()) as updated_at | COALESCE(legacy_data.modified_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 17 | created_by, modified_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by IS NOT NULL AND TRIM(legacy_data.created_by) != '' THEN TRIM(legacy_data.created_by) ELSE NULL END::varchar, NULL::v... |
| 18 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active::boolean = true THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active::boolean = true THEN 0 ELSE 2 END |

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

Full migration context: `04-migration-scripts/idp/seafarer/user_profiles_migration.sql`

## Validation

- Run `05-validation/idp/user_profiles_validation.sql` if available
- Run `06-rollback/idp/user_profiles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
