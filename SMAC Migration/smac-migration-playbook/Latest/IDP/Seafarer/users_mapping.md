# Table Mapping: "Users" → users (+ user_profiles, user_roles)

## Overview
- **Legacy Database**: identity_admin_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users" (primary); also reads `"UserCompany"`, `"UserDepartment"`, `"UserRanks"`, `"Company"`, `"Department"`, `"Ranks"`
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Tables**: `users`, `user_profiles`, `user_roles`, `migration.table_mappings`
- **Source Script**: `04-migration-scripts/idp/seafarer/users_migration.sql`

- **Legacy Path**: `identity_admin_prod.public."Users"`
- **New Paths**:
  - `smac_idp_dev.public.users`
  - `smac_idp_dev.public.user_profiles` (one default profile per user)
  - `smac_idp_dev.public.user_roles` (default role by tag, per profile)
  - `migration.table_mappings` (`Users` → `users` only)

### Target tables inserted by this script

| # | Target table | Source / trigger | Rows |
|---|--------------|------------------|------|
| 1 | `public.users` | `public."Users"` (`UserType` = SEAFARER or PRESEACADET) | One per filtered legacy user |
| 2 | `migration.table_mappings` | `Users` → `users` | One per migrated user |
| 3 | `public.user_profiles` | `Users` (default profile, `is_default_profile = true`) | One per migrated user |
| 4 | `public.user_roles` | Default role from `public.roles.tags` (`seafarer` / `pre_sea_cadet`) | One per non-deleted profile (skip duplicates) |

## Business Key

- **Composite Key**: (`username`, `email`)
- **Source (orchestration)**: Users (Seafarer) (`Users` → `users`)

## Migration Notes

- Migrates seafarer and pre-sea cadet users from `identity_admin_prod` in a single script (seafarer subfolder).
- Script contains **4 INSERT blocks** across three target surfaces: `users`, `user_profiles`, `user_roles`, and `migration.table_mappings` (users only).
- **Column Mapping** below documents all INSERT blocks.
- Filter: `UPPER(TRIM(UserType)) IN ('SEAFARER', 'PRESEACADET')` and (`UserName` or `Email` non-empty, or both NULL).
- `user_type` on `users` and profiles: `PRESEACADET` → `user_types` tagged `pre_sea_cadet`; else `user_types` tagged `seafarer`.
- `nationality_id`: legacy `Country` (code) matched to IDP `public.nationalities.code` (not master dblink).
- Company / department / rank on profiles resolved from master `migration.table_mappings` via `smac_master_migration` dblink.
- `user_roles.user_id` references **`user_profiles.id`** (profile PK), not `users.id`. Roles are assigned from seeded `public.roles` by tag (`seafarer` / `pre_sea_cadet`), not from legacy `UserRoles`.
- Profile id uses `migration.resolve_target_id` with composite source key `legacy_user_id || '|PROFILE'` (no `user_profiles` row in `migration.table_mappings`).

## Special Considerations

- Orchestration dependencies: `user_types`, `roles`, `nationalities`, `companies`, `departments`, `ranks` (latter three via master `table_mappings`)
- Requires seeded `user_types` (tags: `seafarer`, `pre_sea_cadet`) and `roles` (tags: `seafarer`, `pre_sea_cadet`) before migration
- `user_roles.user_id` is **`user_profiles.id`**, not `users.id`
- No legacy `UserRoles` migration in this script — default role only

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 9

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_user_type` | Target user_type for SEAFARER users | `user_type_id` | - | - |
| `presea_user_type` | Target user_type for PRESEACADET users | `user_type_id` | - | - |
| `companies_id_mapping` | UserCompany → target company | `source_id`, `target_id` | `identity_admin_prod.public.Company` → `?.?.companies` | `smac_master_migration` |
| `departments_id_mapping` | UserDepartment → target department | `source_id`, `target_id` | `identity_admin_prod.public.Department` → `?.?.departments` | `smac_master_migration` |
| `ranks_id_mapping` | UserRanks → target rank | `source_id`, `target_id` | `identity_admin_prod.public.Ranks` → `?.?.ranks` | `smac_master_migration` |
| `nationality_lookup_by_code` | `Country` code → `nationalities.id` | `norm_key`, `nationality_id` | - | - |
| `users_id_mapping` | Legacy Users id → target users id | `source_id`, `target_id` | `identity_admin_prod.public.Users` → `?.?.users` | - |
| `migration_seafarer_default_role` | Default role for seafarer profiles | `role_id` | - | - |
| `migration_presea_default_role` | Default role for pre-sea cadet profiles | `role_id` | - | - |

### `seafarer_user_type`

- **Purpose**: Resolve `user_types.id` where `tags` contains `seafarer` (prefer exact tag match)
- **Output columns**: user_type_id

```sql
CREATE TEMP TABLE seafarer_user_type AS
WITH scored AS (
    SELECT ut.id,
           MAX(CASE WHEN lower(trim(t)) = 'seafarer' THEN 1 ELSE 0 END) AS prefer_exact
    FROM public.user_types ut
    CROSS JOIN LATERAL unnest(COALESCE(ut.tags, ARRAY[]::text[])) t
    WHERE strpos(lower(COALESCE(t, '')), 'seafarer') > 0
    GROUP BY ut.id
)
SELECT id AS user_type_id FROM scored ORDER BY prefer_exact DESC LIMIT 1;
```

### `presea_user_type`

- **Purpose**: Resolve `user_types.id` where `tags` contains `pre_sea_cadet` (prefer exact tag match)
- **Output columns**: user_type_id

```sql
CREATE TEMP TABLE presea_user_type AS
WITH scored AS (
    SELECT ut.id,
           MAX(CASE WHEN lower(trim(t)) = 'pre_sea_cadet' THEN 1 ELSE 0 END) AS prefer_exact
    FROM public.user_types ut
    CROSS JOIN LATERAL unnest(COALESCE(ut.tags, ARRAY[]::text[])) t
    WHERE strpos(lower(COALESCE(t, '')), 'pre_sea_cadet') > 0
    GROUP BY ut.id
)
SELECT id AS user_type_id FROM scored ORDER BY prefer_exact DESC LIMIT 1;
```

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

- **Purpose**: Resolve `users.nationality_id` from IDP `public.nationalities` by matching legacy `Country` to `code`
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

- **Purpose**: Legacy `Users.Id` → target `users.id` after users INSERT
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

### `migration_seafarer_default_role`

- **Purpose**: Default `role_id` for seafarer profiles (`roles.tags` contains exact `seafarer`)
- **Output columns**: role_id

```sql
CREATE TEMP TABLE migration_seafarer_default_role AS
SELECT r.id AS role_id
FROM public.roles r
WHERE EXISTS (
    SELECT 1 FROM unnest(COALESCE(r.tags, ARRAY[]::text[])) t
    WHERE lower(trim(COALESCE(t, ''))) = 'seafarer'
)
ORDER BY r.updated_at DESC
LIMIT 1;
```

### `migration_presea_default_role`

- **Purpose**: Default `role_id` for pre-sea cadet profiles (`roles.tags` contains exact `pre_sea_cadet`)
- **Output columns**: role_id

```sql
CREATE TEMP TABLE migration_presea_default_role AS
SELECT r.id AS role_id
FROM public.roles r
WHERE EXISTS (
    SELECT 1 FROM unnest(COALESCE(r.tags, ARRAY[]::text[])) t
    WHERE lower(trim(COALESCE(t, ''))) = 'pre_sea_cadet'
)
ORDER BY r.updated_at DESC
LIMIT 1;
```

## Column Mapping

### 1. `public.users` ← `public."Users"`

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `Id` | text | `id` | uuid | Valid UUID in `Id` and not already in target → cast; else `gen_random_uuid()` | Preserves SAC UUID when unique |
| 2 | `UserName` | character varying | `username` | text | `NULLIF(TRIM(COALESCE("UserName", '')), '')` | Nullable |
| 3 | `NormalizedUserName` | character varying | `normalized_username` | text | Trimmed | |
| 4 | `Email` | character varying | `email` | text | Trimmed | |
| 5 | `NormalizedEmail` | character varying | `normalized_email` | text | Trimmed | |
| 6 | `EmailConfirmed` | boolean | `email_confirmed` | boolean | `COALESCE(..., false)` | |
| 7 | `PasswordHash` | text | `password_hash` | text | Direct copy | |
| 8 | `SecurityStamp` | text | `security_stamp` | text | Direct copy | |
| 9 | `ConcurrencyStamp` | text | `concurrency_stamp` | text | Direct copy | |
| 10 | `PhoneNumber` | text | `phone_number` | text | Trimmed | |
| 11 | `PhoneNumberConfirmed` | boolean | `phone_confirmed` | boolean | `COALESCE(..., false)` | |
| 12 | `TwoFactorEnabled` | boolean | `mfa_enabled` | boolean | `COALESCE(..., false)` | |
| 13 | `LockoutEnd` | timestamptz | `lock_out_end` | timestamptz | Direct copy | |
| 14 | `LockoutEnabled` | boolean | `lock_out_enabled` | boolean | `COALESCE(..., false)` | |
| 15 | `AccessFailedCount` | integer | `failed_login_attempts` | integer | `COALESCE(..., 0)` | |
| 16 | `FirstName` | character varying | `first_name` | text | Trimmed | |
| 17 | `LastName` | character varying | `last_name` | text | Trimmed | |
| 18 | `UserType` | character varying | `user_type` | uuid | `PRESEACADET` → `presea_user_type`; else `seafarer_user_type` | From `user_types.tags` |
| 19 | `Country` | character varying | `nationality` | text | Trimmed country code as label | |
| 20 | `Country` | character varying | `nationality_id` | uuid | `nationality_lookup_by_code` on `UPPER(TRIM(Country))` | Match `nationalities.code` |
| 21 | — | — | `last_login` | timestamptz | `NULL` | Not in source |
| 22 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | |
| 23 | `DeletedAt` | timestamptz | `status` | integer | Deleted / Active constants | `deleted_at` drives status (Case 1) |
| 24 | `CreatedAt` | timestamptz | `created_at` | timestamptz | `COALESCE(CreatedAt, NOW())` | |
| 25 | `ModifiedAt` | timestamptz | `updated_at` | timestamptz | `COALESCE(ModifiedAt, NOW())` | |
| 26 | `Id` | text | `audit_info` | jsonb | `migration.build_audit_info(...)` \|\| `jsonb_build_object('legacy_id', id_text)` | |

**SAC columns not migrated to `users`:** `UserCompany` / `UserDepartment` / `UserRanks` join data — used for profile FKs; `ActualCdcNumber`, `CdcNumber` — on `user_profiles`; `GdPrConsentAcceptedat`, `Gdpr_Consent` — `user_consents_migration.sql`; `IsActive`, `CreatedBy`, `ModifiedBy` — not used.

---

### 2. `migration.table_mappings` ← `Users` (users block)

| # | Source field | New column | Transformation | Notes |
|---|--------------|------------|----------------|-------|
| 1 | `Users.Id` | `source_id` | `legacy_data.id_text` | |
| 2 | — | `target_id` | `u.id` | Join on `audit_info->>'legacy_id'` |
| 3 | — | `source_db` / `source_table` | `identity_admin_prod`, `Users` | Fixed |
| 4 | — | `target_table` | `users` | No `user_profiles` mapping stored in this script |

---

### 3. `public.user_profiles` ← `Users` (default profile)

| # | Legacy Column / Source | New Column | Transformation | Notes |
|---|------------------------|------------|----------------|-------|
| 1 | `Id` | `id` | `migration.resolve_target_id(..., id_text \|\| '\|PROFILE', ..., 'user_profiles', ...)` | Idempotent composite source key |
| 2 | `UserCompany` | `company_id` | `companies_id_mapping.target_id` via `company_source_key` | First company per user in staging |
| 3 | — | `is_default_profile` | `true` | One default profile per user |
| 4 | — | `vessel_id`, `designation_id` | `NULL` | Not populated |
| 5 | `UserDepartment` | `department_id` | `departments_id_mapping.target_id` via `department_source_key` | First department per user |
| 6 | `UserRanks` | `rank_id` | `ranks_id_mapping.target_id` via `rank_source_key` | First rank per user |
| 7 | `FirstName`, `LastName`, `Email`, `PhoneNumber` | same | Trimmed from legacy user | |
| 8 | `UserType` | `user_type` | `PRESEACADET` → `presea_user_type`; else `seafarer_user_type` | Same as `users` |
| 9 | `Id` | `user_id` | `users_id_mapping.target_id` | FK to `public.users.id` |
| 10 | `ActualCdcNumber`, `CdcNumber` | `cdc_number` | `COALESCE(ActualCdcNumber, CdcNumber)` trimmed | Profile-only field |
| 11 | `DeletedAt` | `deleted_at`, `status`, `effective_from` | Preserve `deleted_at`; status from deletion; `effective_from = NOW()` when active | |
| 12 | `Id` | `audit_info` | `legacy_user_id`, `migration_source`, `migrated_at` | |
| 13 | — | `tenant_id` | `:'DEFAULT_TENANT_ID'::uuid` | |
| 14 | — | `workflow_status` | `:'DEFAULT_WORKFLOW_STATUS'::integer` | |
| 15 | — | `user_scope` | `0` | |
| 16 | — | `external_company_id`, `agent_id`, `crew_code`, etc. | `NULL` / defaults | Not populated for seafarer |

**Source keys for FK lookups:** `company_source_key`, `department_source_key`, `rank_source_key` built from legacy id text or `NAME:` + uppercased name (max 92 chars).

---

### 4. `public.user_roles` ← default role by `UserType` (not legacy `UserRoles`)

| # | Legacy / Source | New Column | Transformation | Notes |
|---|-----------------|------------|----------------|-------|
| 1 | — | `id` | `gen_random_uuid()` | |
| 2 | `Users.Id` (via profile) | `user_id` | `user_profiles.id` | **Profile PK**, not `users.id` |
| 3 | `UserType` | `role_id` | `PRESEACADET` → `migration_presea_default_role`; else `migration_seafarer_default_role` | From `roles.tags`, not legacy `RoleId` |
| 4 | — | `assigned_by` | `NULL` | |
| 5 | `UserType` | `role_code` | `'pre_sea_cadet'` or `'seafarer'` | Literal tag string |
| 6 | — | `archived_at`, `deleted_at` | `NULL` | |
| 7 | — | `created_at`, `updated_at` | `NOW()` | |
| 8 | `Users.Id` | `audit_info` | `legacy_user_id`, `assignment_source = 'users_migration_default_role'` | No `legacy_role_id` |
| 9 | — | `tenant_id` | `:'DEFAULT_TENANT_ID'::uuid` | |
| 10 | — | `status` | `:'STATUS_ACTIVE'::integer` | |

Only non-deleted profiles (`user_profiles.deleted_at IS NULL`). Skips when `(profile_id, role_id)` already exists.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `user_types` (tags: `seafarer`, `pre_sea_cadet`)
- `roles` (tags: `seafarer`, `pre_sea_cadet` — default role assignment)
- `nationalities` (for `nationality_id` code lookup on IDP)
- `companies`, `departments`, `ranks` (mappings on master DB via `smac_master_migration`)

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
**Purpose**: Legacy `Users.Id` → target `users.id` after users INSERT
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

### 6. Seafarer / Pre-sea User Type Resolution
**Output columns**: `user_type_id`

`seafarer_user_type` and `presea_user_type` resolve from `public.user_types.tags` (substring match with preference for exact tag `seafarer` / `pre_sea_cadet`).

### 7. Default Role Resolution (by tag)
**Output columns**: `role_id`

`migration_seafarer_default_role` and `migration_presea_default_role` pick the most recently updated `public.roles` row whose `tags[]` contains the exact tag. Used for `user_roles` INSERT — not legacy `UserRoles`.

Full migration context: `04-migration-scripts/idp/seafarer/users_migration.sql`

## Validation

- Run `05-validation/idp/seafarer/users_validation.sql` if available
- Run `06-rollback/idp/seafarer/users_rollback.sql` if rollback is required

## Document Status

Updated to document all 4 INSERT blocks: `users`, `user_profiles`, `user_roles` (default role by tag), and `migration.table_mappings` (users only). Includes profile-level `user_id` FK semantics and tag-based role assignment (no legacy `UserRoles`).
