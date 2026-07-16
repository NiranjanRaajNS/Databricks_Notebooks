# Table Mapping: "Users" → users

## Overview
- **Legacy Database**: identity_admin_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: users
- **Source Script**: `04-migration-scripts/idp/seafarer/users_migration.sql`

- **Legacy Path**: `identity_admin_prod.public."Users"`
- **New Path**: `smac_idp_dev.public.users`

## Business Key

- **Composite Key**: (`username`, `email`)
- **Source (orchestration)**: Users (Seafarer) (`Users` → `users`)

## Migration Notes

- Migrates seafarer users from IdentityAdmin_prod database. Separate from shore users migration. Uses seafarer subfolder for migration scripts.

## Special Considerations

- Orchestration dependencies: `roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `companies_id_mapping` | FK lookup | `source_id`, `target_id` | `identity_admin_prod.public.Company` → `?.?.companies` | `smac_master_migration` |
| `departments_id_mapping` | FK lookup | `source_id`, `target_id` | `identity_admin_prod.public.Department` → `?.?.departments` | `smac_master_migration` |
| `ranks_id_mapping` | FK lookup | `source_id`, `target_id` | `identity_admin_prod.public.Ranks` → `?.?.ranks` | `smac_master_migration` |
| `nationality_lookup_by_code` | FK lookup | `norm_key`, `nationality_id` | - | - |
| `users_id_mapping` | FK lookup | `source_id`, `target_id` | `identity_admin_prod.public.Users` → `?.?.users` | - |

### `companies_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=identity_admin_prod, source_schema=public, source_table=Company, target_table=companies
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Company'
      AND target_db = current_database()::text
      AND target_table = 'companies'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `departments_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=identity_admin_prod, source_schema=public, source_table=Department, target_table=departments
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Department'
      AND target_db = current_database()::text
      AND target_table = 'departments'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `ranks_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=identity_admin_prod, source_schema=public, source_table=Ranks, target_table=ranks
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Ranks'
      AND target_db = current_database()::text
      AND target_table = 'ranks'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `nationality_lookup_by_code`

- **Output columns**: norm_key, nationality_id

```sql
CREATE TEMP TABLE nationality_lookup_by_code AS
SELECT DISTINCT ON (UPPER(TRIM(code)))
    UPPER(TRIM(code)) AS norm_key,
    id AS nationality_id
FROM public.nationalities
WHERE code IS NOT NULL AND TRIM(code) <> ''
ORDER BY UPPER(TRIM(code)), id;
```

### `users_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=identity_admin_prod, source_schema=public, source_table=Users, target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'identity_admin_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_db = current_database()::text
  AND target_table = 'users';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id_text | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'identity_admin_prod'::varchar(100), 'public'::varchar(100), 'Users'::varchar(100), legacy_data.id_text || '|PROFILE', current_database()::text::var... |
| 2 | derived | - | company_id | - | company_map.target_id | company_map.target_id |
| 3 | derived | - | is_default_profile | - | true AS is_default_profile | true |
| 4 | - | - | vessel_id | - | NULL | NULL::uuid |
| 5 | derived | - | department_id | - | department_map.target_id | department_map.target_id |
| 6 | - | - | designation_id | - | NULL | NULL::uuid |
| 7 | derived | - | rank_id | - | rank_map.target_id | rank_map.target_id |
| 8 | first_name | - | first_name | - | NULLIF(TRIM(COALESCE(legacy_data.first_name, '')), '') AS first_name | NULLIF(TRIM(COALESCE(legacy_data.first_name, '')), '') |
| 9 | last_name | - | last_name | - | NULLIF(TRIM(COALESCE(legacy_data.last_name, '')), '') AS last_name | NULLIF(TRIM(COALESCE(legacy_data.last_name, '')), '') |
| 10 | - | - | employee_id | - | NULL | NULL::varchar(50) |
| 11 | email | - | email | - | NULLIF(TRIM(COALESCE(legacy_data.email, '')), '') AS email | NULLIF(TRIM(COALESCE(legacy_data.email, '')), '') |
| 12 | phone_number | - | phone_number | - | NULLIF(TRIM(COALESCE(legacy_data.phone_number, '')), '') AS phone_number | NULLIF(TRIM(COALESCE(legacy_data.phone_number, '')), '') |
| 13 | source_user_type_norm | - | user_type | - | CASE legacy_data.source_user_type_norm WHEN 'PRESEACADET' THEN (SELECT user_type_id FROM presea_user_type) ELSE (SELECT user_type_id FROM seafarer_user_type) END AS user_type | CASE legacy_data.source_user_type_norm WHEN 'PRESEACADET' THEN (SELECT user_type_id FROM presea_user_type) ELSE (SELECT user_type_id FROM seafarer_user_type) END |
| 14 | - | - | profile_picture | - | NULL | NULL::varchar(255) |
| 15 | derived | - | user_id | - | user_map.target_id AS user_id | user_map.target_id |
| 16 | - | - | attributes | - | NULL | NULL::jsonb |
| 17 | - | - | mfa_config | - | NULL | NULL::jsonb |
| 18 | - | - | archived_at | - | NULL | NULL::timestamp |
| 19 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 20 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 21 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 22 | id_text | - | audit_info | - | jsonb_build_object( 'legacy_user_id', legacy_data.id_text, 'migration_source', 'identity_admin_prod', 'migrated_at', NOW() ) AS audit_info | jsonb_build_object( 'legacy_user_id', legacy_data.id_text, 'migration_source', 'identity_admin_prod', 'migrated_at', NOW() ) |
| 23 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 24 | actual_cdc_number, cdc_number | - | cdc_number | - | NULLIF(TRIM(COALESCE(legacy_data.actual_cdc_number, legacy_data.cdc_number, '')), '')::varchar(100) AS cdc_number | NULLIF(TRIM(COALESCE(legacy_data.actual_cdc_number, legacy_data.cdc_number, '')), '')::varchar(100) |
| 25 | deleted_at | - | effective_from | - | CASE WHEN legacy_data.deleted_at IS NULL THEN NOW() ELSE NULL::timestamp END AS effective_ | CASE WHEN legacy_data.deleted_at IS NULL THEN NOW() ELSE NULL::timestamp END AS effective_ |
| 26 | - | - | expired_at | - | See source script | See source script |
| 27 | - | - | reason_id | - | See source script | See source script |
| 28 | - | - | remarks | - | See source script | See source script |
| 29 | - | - | lock_out_enabled | - | See source script | See source script |
| 30 | - | - | crew_code | - | See source script | See source script |
| 31 | - | - | agent_id | - | See source script | See source script |
| 32 | - | - | status | - | See source script | See source script |
| 33 | - | - | user_scope | - | See source script | See source script |
| 34 | - | - | parent_id | - | See source script | See source script |
| 35 | - | - | tags | - | See source script | See source script |
| 36 | - | - | workflow_status | - | See source script | See source script |
| 37 | - | - | external_company_id | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Companies ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Company` → `companies` (source_db=`identity_admin_prod`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Company'
      AND target_db = current_database()::text
      AND target_table = 'companies'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 2. Departments ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Department` → `departments` (source_db=`identity_admin_prod`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Department'
      AND target_db = current_database()::text
      AND target_table = 'departments'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 3. Ranks ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Ranks` → `ranks` (source_db=`identity_admin_prod`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE source_db = 'identity_admin_prod'
      AND source_schema = 'public'
      AND source_table = 'Ranks'
      AND target_db = current_database()::text
      AND target_table = 'ranks'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 4. Nationality Lookup By Code ID Mapping
**Output columns**: `norm_key, nationality_id`

```sql
CREATE TEMP TABLE nationality_lookup_by_code AS
SELECT DISTINCT ON (UPPER(TRIM(code)))
    UPPER(TRIM(code)) AS norm_key,
    id AS nationality_id
FROM public.nationalities
WHERE code IS NOT NULL AND TRIM(code) <> ''
ORDER BY UPPER(TRIM(code)), id;
```

### 5. Users ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Users` → `users` (source_db=`identity_admin_prod`)

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'identity_admin_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_db = current_database()::text
  AND target_table = 'users';
```

Full migration context: `04-migration-scripts/idp/seafarer/users_migration.sql`

## Validation

- Run `05-validation/idp/users_validation.sql` if available
- Run `06-rollback/idp/users_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
