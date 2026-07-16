# Table Mapping: "Users" → users (+ user_profiles, user_roles)

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users" (primary); also reads `"UserRoles"`, `"UserAllocatedCompany"`, `"UserCompany"`, `"UserDepartment"`, `"UserDesignation"`, `"UserServiceType"`, `"Roles"`, `"Company"`, etc.
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Tables**: `users`, `user_profiles`, `user_roles`, `migration.table_mappings`
- **Source Script**: `04-migration-scripts/idp/users_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Users"`
- **New Paths**:
  - `smac_idp_dev.public.users`
  - `smac_idp_dev.public.user_profiles` (default + additional allocated-company profiles)
  - `smac_idp_dev.public.user_roles` (per profile, from legacy `UserRoles`)
  - `migration.table_mappings` (`Users` → `users`, `Users` → `user_profiles`)

### Target tables inserted by this script

| # | Target table | Source / trigger | Rows |
|---|--------------|------------------|------|
| 1 | `public.users` | `public."Users"` | One per filtered legacy user |
| 2 | `migration.table_mappings` | `Users` → `users` | One per migrated user |
| 3 | `public.user_profiles` | `Users` (default profile, `is_default_profile = true`) | One per migrated user |
| 4 | `migration.table_mappings` | `Users` → `user_profiles` (default profile only) | One per migrated user |
| 5 | `public.user_profiles` | `UserAllocatedCompany` (additional profiles, `is_default_profile = false`) | One per allocated company (deduped vs `UserCompany`) |
| 6 | `public.user_roles` | `UserRoles` via `shore_legacy_role_target_resolution` | Legacy role × each non-deleted profile for that account |
| 7 | `public.user_roles` | `UserRoles` via `fallback_role_mapping` | Fallback users only; per profile |
| 8 | `public.user_roles` | `user_types.default_role_id` | Remaining fallback users with default user type; per profile |

## Business Key

- **Composite Key**: (`username`, `email`)
- **Source (orchestration)**: Users (`Users` → `users`)

## Migration Notes

- Migrates Shore users and related profile/role data from synergy_identity_shore_prod in a single script.
- Script contains **8 INSERT blocks** across four target surfaces: `users`, `user_profiles` (×2), `user_roles` (×3), and `migration.table_mappings` (×2).
- **Column Mapping** below documents all INSERT blocks (not only `public.users`).
- `user_type` on `users` and default profiles resolved via `user_type_mapping` (ServiceType, Company TenantId, UserAllocatedCompany, fallback role, default).
- `nationality_id` resolved from master `public.nationalities` via dblink `smac_master_migration` (match by name, then code).
- `user_roles.user_id` references **`user_profiles.id`** (profile PK), not `users.id`; the same legacy role set is applied to every non-deleted profile for the account.
- `role_id` resolved by matching legacy `Roles.Name` / `NormalizedName` to target `public.roles` (preferring `roles.user_type_id` from `user_type_mapping`), with `fallback_role_mapping` for name variants.
- Filter: rows where `UserName` or `Email` is non-empty after trim.

## Special Considerations

- Orchestration dependencies: `roles`, `user_types`, `companies`, `agents`, `departments`, `designations`, `ranks`, master `nationalities`
- `user_roles.user_id` is **`user_profiles.id`**, not `users.id`; roles are duplicated onto every profile for the account.
- Legacy `RoleId` is not copied directly; target `role_id` is resolved by role **name** (+ `fallback_role_mapping`) against `public.roles`.

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 17

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `user_service_type_mapping` | UserServiceType → Recruitment/Technical service type ids | `user_id_text`, `service_type_id` | - | `synergy_identity_shore_prod` |
| `companies_id_mapping` | FK lookup for companies | `source_id`, `target_id` | `synergy_master.public.ship_management_companies` → `?.?.companies` | `smac_master_migration` |
| `departments_id_mapping` | FK lookup for departments | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Department` → `?.?.departments` | `smac_master_migration` |
| `ranks_id_mapping` | FK lookup for ranks | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Ranks` → `?.?.ranks` | - |
| `designations_id_mapping` | FK lookup for designations | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Designation` → `?.?.designations` | `smac_master_migration` |
| `smac_master_nationality_by_name` | Nationality UUID by name | `norm_key`, `nationality_id` | - | `smac_master_migration` |
| `smac_master_nationality_by_code` | Nationality UUID by code (fallback) | `norm_key`, `nationality_id` | - | `smac_master_migration` |
| `user_company_id_mapping` | UserCompany → target company/agent | `source_user_id`, `target_company_id`, `company_tenant_id`, `agent_id` | - | `synergy_identity_shore_prod` |
| `default_profile_company_resolved` | Default profile `company_id` (UserCompany preferred, else first allocated) | `source_user_id`, `target_company_id`, `company_tenant_id`, `agent_id` | - | - |
| `fallback_role_mapping` | Legacy role name → target role name | `target_role_name`, `source_role_name` | - | - |
| `source_user_roles_all` | Legacy UserRoles + role names for migrated users | `user_id_text`, `role_id_text`, `role_name`, `role_normalized_name` | - | `synergy_identity_shore_prod` |
| `user_type_mapping` | Resolve `user_type_id` per legacy user | `source_user_id`, `user_type_id` | - | - |
| `user_allocated_company_id_mapping` | UserAllocatedCompany → target company/agent | `source_user_id`, `source_company_id`, `target_company_id`, `company_tenant_id`, `agent_id` | - | `synergy_identity_shore_prod` |
| `user_department_id_mapping` | UserDepartment → target department | `source_user_id`, `target_department_id` | - | `synergy_identity_shore_prod` |
| `user_designation_id_mapping` | UserDesignation → target designation | `source_user_id`, `target_designation_id` | - | `synergy_identity_shore_prod` |
| `users_id_mapping` | Legacy Users id → target users id | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Users` → `?.?.users` | - |
| `shore_legacy_role_target_resolution` | Legacy UserRoles row → target `role_id` / `role_code` | `user_id_text`, `role_id_text`, `role_id`, `role_code` | - | - |

### `user_service_type_mapping`

- **Output columns**: ust.user_id_text, ust.service_type_id
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_service_type_mapping AS
SELECT
        ust.user_id_text,
        ust.service_type_id
    FROM dblink('synergy_identity_shore_prod', $dblink$
        SELECT "UserId"::text AS user_id_text, "ServiceTypeId" AS service_type_id FROM public."UserServiceType"
    $dblink$) AS ust(user_id_text text, service_type_id integer)
    WHERE ust.user_id_text IS NOT NULL AND ust.service_type_id IS NOT NULL
      AND ust.service_type_id IN (
          SELECT recruitment_id FROM service_type_ids WHERE recruitment_id IS NOT NULL
          UNION
          SELECT technical_id FROM service_type_ids WHERE technical_id IS NOT NULL
      );
```

### `companies_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=synergy_master, source_schema=public, source_table=ship_management_companies, target_table=companies
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_master'
          AND source_schema = 'public'
          AND source_table = 'ship_management_companies'
          AND target_db = current_database()::text
          AND target_table = 'companies'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `departments_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=synergy_identity_shore_prod, source_schema=public, source_table=Department, target_table=departments
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_identity_shore_prod'
          AND source_schema = 'public'
          AND source_table = 'Department'
          AND target_db = current_database()::text
          AND target_table = 'departments'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `ranks_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=synergy_identity_shore_prod, source_schema=public, source_table=Ranks, target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'synergy_identity_shore_prod'
  AND source_schema = 'public'
  AND source_table = 'Ranks'
  AND target_db = current_database()::text
  AND target_table = 'ranks';
```

### `designations_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=synergy_identity_shore_prod, source_schema=public, source_table=Designation, target_table=designations
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE designations_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_identity_shore_prod'
          AND source_schema = 'public'
          AND source_table = 'Designation'
          AND target_db = current_database()::text
          AND target_table = 'designations'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### `smac_master_nationality_by_name`

- **Purpose**: Resolve `users.nationality_id` from master `public.nationalities.name`
- **Output columns**: norm_key, nationality_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE smac_master_nationality_by_name AS
SELECT DISTINCT ON (UPPER(TRIM(name)))
    UPPER(TRIM(name)) AS norm_key,
    id AS nationality_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT id, name
        FROM public.nationalities
        WHERE name IS NOT NULL AND TRIM(name) <> ''
    $dblink_query$
) AS n(id uuid, name text)
ORDER BY UPPER(TRIM(name)), id;
```

### `smac_master_nationality_by_code`

- **Purpose**: Fallback nationality lookup by `public.nationalities.code` when name match fails
- **Output columns**: norm_key, nationality_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE smac_master_nationality_by_code AS
SELECT DISTINCT ON (UPPER(TRIM(code)))
    UPPER(TRIM(code)) AS norm_key,
    id AS nationality_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT id, code
        FROM public.nationalities
        WHERE code IS NOT NULL AND TRIM(code) <> ''
    $dblink_query$
) AS c(id uuid, code text)
ORDER BY UPPER(TRIM(code)), id;
```

### `user_company_id_mapping`

- **Output columns**: data.user_id_text, data.company_normalized_name, data.company_name, data.company_tenant_id
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_company_id_mapping AS
WITH user_company_source AS (
    SELECT
        data.user_id_text,
        data.company_normalized_name,
        data.company_name,
        data.company_tenant_id
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                uc."UserId"::text AS user_id_text,
                c."NormalizedName" AS company_normalized_name,
                c."Name" AS company_name,
                c."TenantId" AS company_tenant_id
            FROM public."UserCompany" uc
            INNER JOIN public."Company" c ON c."Id" = uc."CompanyId"
            WHERE uc."UserId" IS NOT NULL
              AND uc."CompanyId" IS NOT NULL
              AND c."NormalizedName" IS NOT NULL
              AND TRIM(c."NormalizedName") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        company_normalized_name text,
        company_name text,
        company_tenant_id integer
    )
)
SELECT DISTINCT ON (ucs.user_id_text)
    ucs.user_id_text AS source_user_id,
    target_companies.id AS target_company_id,
    ucs.company_tenant_id,
    ucs.company_name AS source_company_name,
    CASE
        WHEN ucs.company_tenant_id = 2...
```

### `fallback_role_mapping`

- **Output columns**: target_role_name, source_role_name

```sql
CREATE TEMP TABLE fallback_role_mapping AS
SELECT target_role_name, source_role_name FROM (VALUES
    ('Technical Superintendent', 'Technical_Superintendent'),
    ('Marine Superintendent', 'Marine_Superintendent'),
    ('Marine Manager', 'Marine_Manager'),
    ('Technical Manager', 'Technical_Manager'),
    ('Environmental Compliance Officer', 'Environmental_Compliance_Officer'),
    ('Fleet Manager', 'Fleet Manager'),
    ('Documentation Manager', 'Documentation Manager'),
    ('Documentation Executive', 'Documentation Executive'),
    ('Crew Coordinator', 'Crew Coordinator'),
    ('PO_Admin', 'PO_Admin'),
    ('PO_Coordinator', 'PO_Coordinator'),
    ('Accounts Payable', 'Accounts Payable'),
    ('Authorized Signatory', 'Authorized Signatory'),
    ('Manning Agent', 'Manning Agent'),
    ('Manning Manager', 'Manning_Manager'),
    ('Competency Cell', 'Competency Cell'),
    ('Training Coordinator', 'Training Coordinator'),
    ('Cadet Training Officer', 'Cadet Training Officer'),
    ('Pre-sea Cadet Admin', 'Pre-sea Cadet Admin'),
    ('QHSE Head', 'QHSE Head'),
    ('QHSE Team', 'QHSE Team'),
    ('QHSE Manager', 'QHSE Manager'),
    ('QHSE Group Head', 'QHSE Group Head'),
 ...
```

### `user_type_mapping`

- **Purpose**: Resolve `user_type_id` per legacy user (ServiceType, tenant, allocated company, fallback role, default)
- **Output columns**: source_user_id, user_type_id

```sql
CREATE TEMP TABLE user_type_mapping AS
SELECT DISTINCT ON (legacy_data.id_text)
    legacy_data.id_text AS source_user_id,
    CASE

        WHEN fallback_utm.user_type_id IS NOT NULL THEN fallback_utm.user_type_id

        WHEN excluded_no_role.user_id_text IS NOT NULL AND (SELECT user_type_id FROM default_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM default_user_type LIMIT 1)

        WHEN ust.service_type_id = (SELECT recruitment_id FROM service_type_ids)
             AND (SELECT user_type_id FROM crewing_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM crewing_user_type LIMIT 1)
        WHEN ust.service_type_id = (SELECT technical_id FROM service_type_ids)
             AND (SELECT user_type_id FROM technical_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM technical_user_type LIMIT 1)

        WHEN ust.user_id_text IS NULL AND ucm.company_tenant_id = 2
        THEN (SELECT user_type_id FROM manning_user_type LIMIT 1)
        WHEN ust.user_id_text IS NULL AND (SELECT user_type_id FROM crewing_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM crewing_user_type LIMIT 1)

        WHEN allocate...
```

### `user_allocated_company_id_mapping`

- **Output columns**: data.user_id_text, data.company_id_text, data.company_normalized_name, data.company_name, data.company_tenant_id
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_allocated_company_id_mapping AS
WITH user_allocated_company_source AS (
    SELECT
        data.user_id_text,
        data.company_id_text,
        data.company_normalized_name,
        data.company_name,
        data.company_tenant_id
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                uac."UserId"::text AS user_id_text,
                uac."CompanyId"::text AS company_id_text,
                c."NormalizedName" AS company_normalized_name,
                c."Name" AS company_name,
                c."TenantId" AS company_tenant_id
            FROM public."UserAllocatedCompany" uac
            INNER JOIN public."Company" c ON c."Id" = uac."CompanyId"
            WHERE uac."UserId" IS NOT NULL
              AND uac."CompanyId" IS NOT NULL
              AND c."NormalizedName" IS NOT NULL
              AND TRIM(c."NormalizedName") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        company_id_text text,
        company_normalized_name text,
        company_name text,
        company_tenant_id integer
    )
)
SELECT
    uacs.user_id_text AS source_user_id,
    uacs.company_id_text AS source_company_...
```

### `user_department_id_mapping`

- **Purpose**: UserDepartment → target department by name match
- **Output columns**: data.user_id_text, data.department_name
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_department_id_mapping AS
WITH user_department_source AS (
    SELECT
        data.user_id_text,
        data.department_name
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                ud."UserId"::text AS user_id_text,
                d."Name" AS department_name
            FROM public."UserDepartment" ud
            INNER JOIN public."Department" d ON d."Id" = ud."DepartmentId"
            WHERE ud."UserId" IS NOT NULL
              AND ud."DepartmentId" IS NOT NULL
              AND d."Name" IS NOT NULL
              AND TRIM(d."Name") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        department_name text
    )
)
SELECT DISTINCT ON (uds.user_id_text)
    uds.user_id_text AS source_user_id,
    target_departments.id AS target_department_id
FROM user_department_source uds
JOIN public.departments target_departments
  ON UPPER(TRIM(target_departments.name)) = UPPER(TRIM(uds.department_name))
ORDER BY uds.user_id_text, target_departments.created_at;
```

### `user_designation_id_mapping`

- **Output columns**: data.user_id_text, data.designation_id_text
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_designation_id_mapping AS
WITH user_designation_source AS (
    SELECT
        data.user_id_text,
        data.designation_id_text
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                ud."UserId"::text AS user_id_text,
                ud."DesignationId"::text AS designation_id_text
            FROM public."UserDesignation" ud
            WHERE ud."UserId" IS NOT NULL
              AND ud."DesignationId" IS NOT NULL
    $dblink_query$) AS data(
        user_id_text text,
        designation_id_text text
    )
)
SELECT DISTINCT ON (uds.user_id_text)
    uds.user_id_text AS source_user_id,
    des_map.target_id AS target_designation_id
FROM user_designation_source uds
JOIN designations_id_mapping des_map ON des_map.source_id = uds.designation_id_text
JOIN public.designations target_designations ON target_designations.id = des_map.target_id
ORDER BY uds.user_id_text, target_designations.created_at;
```

### `source_user_roles_all`

- **Purpose**: Legacy `UserRoles` joined to `Roles` for users in migration scope
- **Output columns**: user_id_text, role_id_text, role_name, role_normalized_name
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE source_user_roles_all AS
SELECT data.user_id_text, data.role_id_text, data.role_name, data.role_normalized_name
FROM dblink('synergy_identity_shore_prod', $dblink_query$
    SELECT ur."UserId"::text AS user_id_text, ur."RoleId"::text AS role_id_text,
           r."Name" AS role_name, r."NormalizedName" AS role_normalized_name
    FROM public."UserRoles" ur
    LEFT JOIN public."Roles" r ON r."Id" = ur."RoleId"
    WHERE ur."UserId" IS NOT NULL AND ur."RoleId" IS NOT NULL
$dblink_query$) AS data(user_id_text text, role_id_text text, role_name text, role_normalized_name text)
WHERE EXISTS (
    SELECT 1 FROM legacy_users lu
    WHERE LOWER(TRIM(lu.id_text)) = LOWER(TRIM(data.user_id_text))
);
```

### `default_profile_company_resolved`

- **Purpose**: Default profile `company_id`: `UserCompany` mapping when present, else first `UserAllocatedCompany` row
- **Output columns**: source_user_id, target_company_id, company_tenant_id, agent_id

```sql
CREATE TEMP TABLE default_profile_company_resolved AS
SELECT
    lu.id_text AS source_user_id,
    COALESCE(ucm.target_company_id, uac_first.target_company_id) AS target_company_id,
    CASE WHEN ucm.target_company_id IS NOT NULL THEN ucm.company_tenant_id ELSE uac_first.company_tenant_id END AS company_tenant_id,
    CASE WHEN ucm.target_company_id IS NOT NULL THEN ucm.agent_id ELSE uac_first.agent_id END AS agent_id
FROM legacy_users lu
LEFT JOIN user_company_id_mapping ucm ON ucm.source_user_id = lu.id_text
LEFT JOIN LATERAL (
    SELECT uacf.target_company_id, uacf.company_tenant_id, uacf.agent_id
    FROM user_allocated_company_id_mapping uacf
    WHERE uacf.source_user_id = lu.id_text
    ORDER BY uacf.source_company_id
    LIMIT 1
) uac_first ON TRUE;
```

### `users_id_mapping`

- **Purpose**: Legacy `Users.Id` → target `users.id` after users INSERT
- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_db=synergy_identity_shore_prod, source_schema=public, source_table=Users, target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'synergy_identity_shore_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_db = current_database()::text
  AND target_table = 'users';
```

### `shore_legacy_role_target_resolution`

- **Purpose**: Map each legacy `(UserId, RoleId)` to one target `public.roles.id` using role name + `user_type_mapping.user_type_id`, with `fallback_role_mapping` for name variants
- **Output columns**: user_id_text, role_id_text, role_id, role_code

```sql
CREATE TEMP TABLE shore_legacy_role_target_resolution AS
SELECT DISTINCT ON (sur.user_id_text, sur.role_id_text)
    sur.user_id_text,
    sur.role_id_text,
    COALESCE(tr_utm.id, tr_any.id) AS role_id,
    COALESCE(tr_utm.code, tr_any.code) AS role_code
FROM source_user_roles_all sur
JOIN users_id_mapping ur_user ON LOWER(TRIM(ur_user.source_id)) = LOWER(TRIM(sur.user_id_text))
JOIN user_type_mapping utm ON LOWER(TRIM(utm.source_user_id)) = LOWER(TRIM(sur.user_id_text))
LEFT JOIN public.roles tr_utm
    ON tr_utm.user_type_id = utm.user_type_id
   AND (
        (sur.role_name IS NOT NULL AND UPPER(TRIM(tr_utm.name)) = UPPER(TRIM(sur.role_name)))
        OR (sur.role_normalized_name IS NOT NULL AND UPPER(TRIM(tr_utm.normalized_name)) = UPPER(TRIM(sur.role_normalized_name)))
        OR EXISTS (
            SELECT 1 FROM fallback_role_mapping frm
            WHERE UPPER(TRIM(frm.source_role_name)) IN (UPPER(TRIM(sur.role_name)), UPPER(TRIM(sur.role_normalized_name)))
              AND UPPER(TRIM(tr_utm.name)) = UPPER(TRIM(frm.target_role_name))
        )
    )
LEFT JOIN LATERAL (
    SELECT r.id, r.code FROM public.roles r
    WHERE /* same name / fallback_role_mapping match as above */
    ORDER BY CASE WHEN r.user_type_id = utm.user_type_id THEN 0 ELSE 1 END, r.id
    LIMIT 1
) tr_any ON tr_utm.id IS NULL
WHERE COALESCE(tr_utm.id, tr_any.id) IS NOT NULL;
```

## Column Mapping

### 1. `public.users` ← `public."Users"`

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per row; legacy `Id` stored in `audit_info.legacy_id` and `migration.table_mappings` |
| 2 | `UserName` | text | `username` | text | `NULLIF(TRIM(COALESCE(user_name, '')), '')` | Empty strings → NULL |
| 3 | `NormalizedUserName` | text | `normalized_username` | text | `NULLIF(TRIM(COALESCE(normalized_user_name, '')), '')` | Direct from source |
| 4 | `Email` | text | `email` | text | `NULLIF(TRIM(COALESCE(email, '')), '')` | Filter requires username or email non-empty |
| 5 | `NormalizedEmail` | text | `normalized_email` | text | `NULLIF(TRIM(COALESCE(normalized_email, '')), '')` | Direct from source |
| 6 | `EmailConfirmed` | boolean | `email_confirmed` | boolean | `COALESCE(email_confirmed, false)` | Default false when NULL |
| 7 | `PasswordHash` | text | `password_hash` | text | Direct copy | Preserved for login continuity |
| 8 | `SecurityStamp` | text | `security_stamp` | text | Direct copy | ASP.NET Identity field |
| 9 | `ConcurrencyStamp` | text | `concurrency_stamp` | text | Direct copy | ASP.NET Identity field |
| 10 | `PhoneNumber` | text | `phone_number` | text | `NULLIF(TRIM(COALESCE(phone_number, '')), '')` | Empty strings → NULL |
| 11 | `PhoneNumberConfirmed` | boolean | `phone_confirmed` | boolean | `COALESCE(phone_confirmed, false)` | Default false |
| 12 | `TwoFactorEnabled` | boolean | `mfa_enabled` | boolean | `COALESCE(mfa_enabled, false)` | Maps 2FA flag |
| 13 | `LockoutEnd` | timestamp with time zone | `lock_out_end` | timestamp with time zone | Direct copy | Account lockout expiry |
| 14 | `LockoutEnabled` | boolean | `lock_out_enabled` | boolean | `COALESCE(lock_out_enabled, false)` | Default false |
| 15 | `AccessFailedCount` | integer | `failed_login_attempts` | integer | `COALESCE(failed_login_attempts, 0)` | Default 0 |
| 16 | `FirstName` | text | `first_name` | text | `NULLIF(TRIM(COALESCE(first_name, '')), '')` | Trimmed |
| 17 | `LastName` | text | `last_name` | text | `NULLIF(TRIM(COALESCE(last_name, '')), '')` | Trimmed |
| 18 | `UserServiceType`, `Company`, `UserAllocatedCompany`, `UserRoles` | — | `user_type` | uuid | `COALESCE(utm.user_type_id, crew_user_type)` | Resolved via `user_type_mapping`; fallback to `crew_user` tag |
| 19 | `Country` | text | `nationality` | text | `NULLIF(TRIM(COALESCE(nationality, '')), '')` | Legacy country text preserved as nationality label |
| 20 | `Country` | text | `nationality_id` | uuid | `smac_master_nationality_by_name` then `smac_master_nationality_by_code` | Master `public.nationalities` via dblink |
| 21 | `lastlogintime` | text | `last_login` | timestamp without time zone | Cast when value matches `^\d{4}-\d{2}-\d{2}` | Otherwise NULL |
| 22 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From `constants.sql` |
| 23 | `deleted_at` | timestamp with time zone | `status` | integer | `deleted_at IS NOT NULL` → `:'STATUS_DELETED'`; else `:'STATUS_ACTIVE'` | Source `deleted_at` hardcoded NULL in staging |
| 24 | `CreatedAt` | timestamp with time zone | `created_at` | timestamp with time zone | `COALESCE(created_at, NOW())` | Direct from source |
| 25 | `CreatedAt` | timestamp with time zone | `updated_at` | timestamp with time zone | `COALESCE(updated_at, NOW())` | Staging sets `updated_at = CreatedAt` |
| 26 | `Id` | text | `audit_info` | jsonb | `migration.build_audit_info(...)` \|\| `jsonb_build_object('legacy_id', id_text)` | Standard SMAC structure + legacy user id |

**SAC columns not migrated to `users`:** Junction/context tables (`UserCompany`, `UserDepartment`, `UserDesignation`, `UserRoles`, `UserServiceType`, `UserAllocatedCompany`) feed lookups and child INSERT blocks.

**SMAC columns not on `users`:** Profile-level fields (`company_id`, `department_id`, etc.) land on `user_profiles`.

---

### 2. `migration.table_mappings` ← `Users` (users block)

| # | Source field | New column | Transformation | Notes |
|---|--------------|------------|----------------|-------|
| 1 | `Users.Id` | `source_id` | `legacy_data.id_text` | Legacy user id as text |
| 2 | — | `target_id` | `u.id` from joined `public.users` | Match on `audit_info->>'legacy_id'` |
| 3 | — | `source_db` / `source_schema` / `source_table` | `synergy_identity_shore_prod`, `public`, `Users` | Fixed |
| 4 | — | `target_db` / `target_schema` / `target_table` | `current_database()`, `public`, `users` | Fixed |
| 5 | — | `migration_direction` | `'SAC_TO_SMAC'` | Fixed |
| 6 | — | `migrated_at` | `NOW()` | Upsert on conflict |

---

### 3. `public.user_profiles` ← `Users` (default profile, `is_default_profile = true`)

| # | Legacy Column / Source | Legacy Type | New Column | New Type | Transformation | Notes |
|---|------------------------|-------------|------------|----------|----------------|-------|
| 1 | `Id` | text/uuid | `id` | uuid | `migration.resolve_target_id(..., 'Users', id_text, ..., 'user_profiles', id_uuid, is_repeated)` | Idempotent when legacy `Id` is UUID |
| 2 | `UserCompany` / `UserAllocatedCompany` | — | `company_id` | uuid | `default_profile_company_resolved.target_company_id` | UserCompany preferred; else first allocated |
| 3 | — | — | `is_default_profile` | boolean | `true` | One default profile per user |
| 4 | — | — | `vessel_id` | uuid | `NULL` | Not populated |
| 5 | `UserDepartment` | — | `department_id` | uuid | `user_department_id_mapping.target_department_id` | Name match to `departments` |
| 6 | `UserDesignation` | — | `designation_id` | uuid | `user_designation_id_mapping.target_designation_id` | Via `designations_id_mapping` |
| 7 | `Ranks` (staged key) | — | `rank_id` | uuid | `ranks_id_mapping.target_id` | From `rank_source_key` when present |
| 8 | `FirstName` | text | `first_name` | text | Trimmed from legacy user | Same as `users` |
| 9 | `LastName` | text | `last_name` | text | Trimmed from legacy user | Same as `users` |
| 10 | — | — | `employee_id` | varchar(50) | `NULL` | Not populated |
| 11 | `Email` | text | `email` | text | Trimmed from legacy user | |
| 12 | `PhoneNumber` | text | `phone_number` | text | Trimmed from legacy user | |
| 13 | (same as users) | — | `user_type` | uuid | `COALESCE(utm.user_type_id, crew_user_type)` | From `user_type_mapping` |
| 14 | — | — | `profile_picture` | varchar(255) | `NULL` | Not populated |
| 15 | `Id` | text | `user_id` | uuid | `users_id_mapping.target_id` | FK to `public.users.id` |
| 16 | — | — | `attributes`, `mfa_config` | jsonb | `NULL` | Not populated |
| 17 | — | — | `archived_at` | timestamp | `NULL` | Not populated |
| 18 | `CreatedAt` | timestamptz | `created_at` | timestamptz | `COALESCE(created_at, NOW())` | |
| 19 | `CreatedAt` | timestamptz | `updated_at` | timestamptz | `COALESCE(updated_at, NOW())` | |
| 20 | `deleted_at` | timestamptz | `deleted_at` | timestamptz | Direct (NULL in staging) | Soft delete on profile |
| 21 | `Id` | text | `audit_info` | jsonb | `legacy_user_id`, `migration_source`, `migrated_at` | |
| 22 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | |
| 23 | — | — | `cdc_number` | varchar(100) | `NULL` | |
| 24 | `deleted_at` | timestamptz | `effective_from` | timestamp | `NOW()` when active; else `NULL` | |
| 25 | — | — | `expired_at`, `reason_id`, `remarks` | — | `NULL` | |
| 26 | — | — | `lock_out_enabled` | boolean | `false` | |
| 27 | — | — | `crew_code`, `agent_id` | — | `NULL` | `agent_id` not set on default profile |
| 28 | `deleted_at` | timestamptz | `status` | integer | Active / Deleted constants | |
| 29 | — | — | `user_scope` | integer | `0` | |
| 30 | — | — | `parent_id`, `tags` | — | `NULL` | |
| 31 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | |
| 32 | `UserCompany` / `UserAllocatedCompany` | — | `external_company_id` | uuid | `default_profile_company_resolved.target_company_id` | Same resolved company as `company_id` |

`ON CONFLICT (id) DO UPDATE` refreshes all mapped columns on re-run.

---

### 4. `migration.table_mappings` ← `Users` (user_profiles block)

| # | Source field | New column | Transformation | Notes |
|---|--------------|------------|----------------|-------|
| 1 | `Users.Id` | `source_id` | `legacy_data.id_text` | Same legacy user id |
| 2 | — | `target_id` | `up.id` | Join `user_profiles` where `audit_info->>'legacy_user_id'` and `is_default_profile = true` |
| 3 | — | `target_table` | `user_profiles` | Only default profile is mapped |

---

### 5. `public.user_profiles` ← `UserAllocatedCompany` (additional profiles)

| # | Legacy Column / Source | New Column | Transformation | Notes |
|---|------------------------|------------|----------------|-------|
| 1 | — | `id` | `gen_random_uuid()` | New UUID per allocated company row |
| 2 | `CompanyId` → company name | `company_id` | `user_allocated_company_id_mapping.target_company_id` | Name match to `companies` / `agents` |
| 3 | — | `is_default_profile` | `false` | Additional profile |
| 4 | `Users` fields | `first_name`, `last_name`, `email`, `phone_number` | Copied from `legacy_users` | |
| 5 | `Company.TenantId` | `user_type` | Tenant `2` → `manning_user_type`; else `COALESCE(utm, doc_user_type)` | Per allocated row |
| 6 | `UserId` | `user_id` | `users_id_mapping.target_id` | FK to account `users.id` |
| 7 | `UserId`, `CompanyId` | `audit_info` | `legacy_user_id`, `legacy_allocated_company_id`, `profile_source = 'UserAllocatedCompany'` | |
| 8 | `Company.TenantId` | `external_company_id` | Manning (`2`): `agent_id` when found; else company id when tenant ≠ 1 | See script CASE |
| 9 | (shared lookups) | `department_id`, `designation_id`, `rank_id` | Same mappings as default profile | Per user, not per allocation |

**Skip rule:** Row omitted when the same `(UserId, CompanyId)` already exists in legacy `UserCompany` (`user_company_legacy_company_ids`).

---

### 6. `public.user_roles` ← `UserRoles` (standard resolution)

Legacy source: `public."UserRoles"` + `public."Roles"` via `source_user_roles_all` → `shore_legacy_role_target_resolution`.

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per assignment |
| 2 | `UserId`¹ | text | `user_id` | uuid | `up.id` (profile PK) | **Not** `users.id`; cross-join all non-deleted `user_profiles` for the account |
| 3 | `RoleId`¹ | text | `role_id` | uuid | `shore_legacy_role_target_resolution.role_id` | Match `roles.name` / `normalized_name` (+ `fallback_role_mapping`), prefer `roles.user_type_id = user_type_mapping.user_type_id` |
| 4 | — | — | `assigned_by` | uuid | `NULL` | |
| 5 | `Roles.Name`¹ | text | `role_code` | text | `shore_legacy_role_target_resolution.role_code` | From matched target role |
| 6 | — | — | `archived_at`, `deleted_at` | timestamptz | `NULL` | |
| 7 | — | — | `created_at`, `updated_at` | timestamptz | `NOW()` | |
| 8 | `UserId`, `RoleId` | text | `audit_info` | jsonb | `legacy_user_id`, `legacy_role_id`, `assignment_source = 'users_migration_from_userroles'` | |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | |
| 10 | — | — | `status` | integer | `:'STATUS_ACTIVE'::integer` | |

¹ Resolved in `source_user_roles_all` / `shore_legacy_role_target_resolution`. Duplicate `(profile_id, role_id)` skipped via `LEFT JOIN public.user_roles existing`.

**Role name mapping:** When legacy `Roles.Name` or `NormalizedName` differs from target (e.g. `Technical_Superintendent` → `Technical Superintendent`), `fallback_role_mapping` supplies the target name before joining `public.roles`.

---

### 7. `public.user_roles` ← `UserRoles` (fallback users, `fallback_role_mapping`)

Same column layout as block 6; used only for users in `fallback_user_type_from_role`.

| # | Key difference | Notes |
|---|----------------|-------|
| `role_id` | `COALESCE(tr_profile.id, tr_fallback.id, tr_any.id)` | Prefer role where `roles.user_type_id = up.user_type`, then fallback user type |
| `audit_info.assignment_source` | `'users_migration_fallback_role_mapping'` | |

---

### 8. `public.user_roles` ← `user_types.default_role_id` (remaining fallback users)

For users in `users_excluded_no_mapped_role` with default user type (`tags` contains `'default'`).

| # | New Column | Transformation | Notes |
|---|------------|----------------|-------|
| `user_id` | `up.id` | Profile PK for each non-deleted profile | |
| `role_id` | `default_user_type.default_role_id` | From `user_types` tagged `default` | |
| `role_code` | `roles.code` | Join on `default_role_id` | |
| `audit_info.assignment_source` | `'users_migration_default_user_type_role'` | No `legacy_role_id` when role is synthetic default | |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `user_types` (tagged: `crew_user`, `manning`, `ext_vendor`, `doc_user`, `crewing`, `technical`, `default`)
- `roles` (name/normalized_name match + `user_type_id`)
- `companies`, `agents` (company/agent resolution for profiles)
- `departments`, `designations`, `ranks` (profile FKs; populated by separate migrations)
- `public.nationalities` on master DB (via `smac_master_migration` dblink)

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. User Service Type ID Mapping
**Output columns**: `ust.user_id_text, ust.service_type_id`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_service_type_mapping AS
SELECT
        ust.user_id_text,
        ust.service_type_id
    FROM dblink('synergy_identity_shore_prod', $dblink$
        SELECT "UserId"::text AS user_id_text, "ServiceTypeId" AS service_type_id FROM public."UserServiceType"
    $dblink$) AS ust(user_id_text text, service_type_id integer)
    WHERE ust.user_id_text IS NOT NULL AND ust.service_type_id IS NOT NULL
      AND ust.service_type_id IN (
          SELECT recruitment_id FROM service_type_ids WHERE recruitment_id IS NOT NULL
          UNION
          SELECT technical_id FROM service_type_ids WHERE technical_id IS NOT NULL
      );
```

### 2. Companies ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `ship_management_companies` → `companies` (source_db=`synergy_master`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_master'
          AND source_schema = 'public'
          AND source_table = 'ship_management_companies'
          AND target_db = current_database()::text
          AND target_table = 'companies'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 3. Departments ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Department` → `departments` (source_db=`synergy_identity_shore_prod`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_identity_shore_prod'
          AND source_schema = 'public'
          AND source_table = 'Department'
          AND target_db = current_database()::text
          AND target_table = 'departments'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 4. Ranks ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Ranks` → `ranks` (source_db=`synergy_identity_shore_prod`)

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'synergy_identity_shore_prod'
  AND source_schema = 'public'
  AND source_table = 'Ranks'
  AND target_db = current_database()::text
  AND target_table = 'ranks';
```

### 5. Designations ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Designation` → `designations` (source_db=`synergy_identity_shore_prod`)
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE designations_id_mapping AS
SELECT source_id, target_id
FROM dblink('smac_master_migration', $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE source_db = 'synergy_identity_shore_prod'
          AND source_schema = 'public'
          AND source_table = 'Designation'
          AND target_db = current_database()::text
          AND target_table = 'designations'
$dblink_query$) AS m(source_id text, target_id uuid);
```

### 6. User Company ID Mapping
**Output columns**: `data.user_id_text, data.company_normalized_name, data.company_name, data.company_tenant_id`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_company_id_mapping AS
WITH user_company_source AS (
    SELECT
        data.user_id_text,
        data.company_normalized_name,
        data.company_name,
        data.company_tenant_id
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                uc."UserId"::text AS user_id_text,
                c."NormalizedName" AS company_normalized_name,
                c."Name" AS company_name,
                c."TenantId" AS company_tenant_id
            FROM public."UserCompany" uc
            INNER JOIN public."Company" c ON c."Id" = uc."CompanyId"
            WHERE uc."UserId" IS NOT NULL
              AND uc."CompanyId" IS NOT NULL
              AND c."NormalizedName" IS NOT NULL
              AND TRIM(c."NormalizedName") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        company_normalized_name text,
        company_name text,
        company_tenant_id integer
    )
)
SELECT DISTINCT ON (ucs.user_id_text)
    ucs.user_id_text AS source_user_id,
    target_companies.id AS target_company_id,
    ucs.company_tenant_id,
    ucs.company_name AS source_company_name,
    CASE
        WHEN ucs.company_tenant_id = 2 THEN target_agents.id
        ELSE NULL::uuid
    END AS agent_id
FROM user_company_source ucs
LEFT JOIN public.companies target_companies
  ON UPPER(TRIM(target_companies.name)) = UPPER(TRIM(ucs.company_normalized_name))
LEFT JOIN public.agents target_agents
  ON ucs.company_tenant_id = 2
  AND UPPER(TRIM(target_agents.name)) = UPPER(TRIM(ucs.company_name))
WHERE


    (ucs.company_tenant_id = 2 AND target_agents.id IS NOT NULL)
    OR (ucs.company_tenant_id <> 2 AND target_companies.id IS NOT NULL)
ORDER BY ucs.user_id_text,


    CASE
        WHEN EXISTS (
            SELECT 1 FROM user_company_source ucs2
            WHERE ucs2.user_id_text = ucs.user_id_text
              AND ucs2.company_tenant_id IS NOT NULL
              AND ucs2.company_tenant_id <> 2
        )
        THEN CASE WHEN COALESCE(ucs.company_tenant_id, -1) = 2 THEN 1 ELSE 0 END
        ELSE CASE WHEN COALESCE(ucs.company_tenant_id, -1) = 2 THEN 0 ELSE 1 END
    END,
    COALESCE(target_companies.created_at, NOW());
```

### 7. Fallback Role ID Mapping
**Output columns**: `target_role_name, source_role_name`

```sql
CREATE TEMP TABLE fallback_role_mapping AS
SELECT target_role_name, source_role_name FROM (VALUES
    ('Technical Superintendent', 'Technical_Superintendent'),
    ('Marine Superintendent', 'Marine_Superintendent'),
    ('Marine Manager', 'Marine_Manager'),
    ('Technical Manager', 'Technical_Manager'),
    ('Environmental Compliance Officer', 'Environmental_Compliance_Officer'),
    ('Fleet Manager', 'Fleet Manager'),
    ('Documentation Manager', 'Documentation Manager'),
    ('Documentation Executive', 'Documentation Executive'),
    ('Crew Coordinator', 'Crew Coordinator'),
    ('PO_Admin', 'PO_Admin'),
    ('PO_Coordinator', 'PO_Coordinator'),
    ('Accounts Payable', 'Accounts Payable'),
    ('Authorized Signatory', 'Authorized Signatory'),
    ('Manning Agent', 'Manning Agent'),
    ('Manning Manager', 'Manning_Manager'),
    ('Competency Cell', 'Competency Cell'),
    ('Training Coordinator', 'Training Coordinator'),
    ('Cadet Training Officer', 'Cadet Training Officer'),
    ('Pre-sea Cadet Admin', 'Pre-sea Cadet Admin'),
    ('QHSE Head', 'QHSE Head'),
    ('QHSE Team', 'QHSE Team'),
    ('QHSE Manager', 'QHSE Manager'),
    ('QHSE Group Head', 'QHSE Group Head'),
    ('Group Head', 'Group Head'),
    ('Group Head', 'Group_Head'),
    ('QHSE Crewing and Training Coordinator', 'QHSE Crewing and Training Coordinator'),
    ('DOC Head', 'DOC Head'),
    ('Crewing Head', 'Crewing Head'),
    ('Sourcing Executive', 'Sourcing Executive'),
    ('Sourcing Manager', 'Sourcing Manager'),
    ('Flag License Executive', 'Flag License Executive'),
    ('Portage Bill Team', 'Portage Bill Team'),
    ('Portage Bill Team Head', 'Portage Bill Team Head'),
    ('Feedback Welfare Committee', 'Feedback Welfare Committee'),
    ('Feedback Welfare Committee Member', 'Feedback Welfare Committee Member'),
    ('Open Reporting-Working Committee', 'Open Reporting-Working Committee'),
    ('Open Reporting-Executive Committee', 'Open Reporting-Executive Committee'),
    ('VP CMS FDL Creator', 'VP CMS FDL Creator'),
    ('VP Insurance FDL Creator', 'VP Insurance FDL Creator'),
    ('VP Accounts PIC Creator', 'VP Accounts PIC Creator'),
    ('VP EMS FDL Creator', 'VP EMS FDL Creator'),
    ('VP Tech Ops Admin', 'VP Tech Ops Admin'),
    ('VP Crewing Admin', 'VP Crewing Admin'),
    ('VP Crewing Admin', 'VP_Crewing_Admin'),
    ('VP Crewing FDL Admin', 'VP Crewing FDL Admin'),
    ('VP Crewing FDL Admin', 'VP_Crewing_FDL_Admin'),
    ('DOC-TechOps FDL Creator', 'DOC-TechOps FDL Creator'),
    ('EFRadmin', 'EFRadmin'),
    ('KaaS PPE Admin', 'KaaS PPE Admin'),
    ('Kaas Vendor', 'Kaas Vendor'),
    ('Tenant Administrator', 'Tenant Administrator'),
    ('Tenant Administrator', 'Tenant_Administrator'),
    ('Default Role', 'Default Role'),
    ('Interviewer', 'Interviewer'),
    ('Activation Key Generator', 'Activation Key Generator'),
    ('Activation Key Generator', 'Activation_Key_Generator'),
    ('Chief Engineer', 'Chief Engineer'),
    ('Chief Engineer', 'Chief_Engineer'),
    ('Chief Officer', 'Chief Officer'),
    ('Chief Officer', 'Chief_Officer'),
    ('Second Engineer', 'Second Engineer'),
    ('Second Engineer', 'Second_Engineer'),
    ('Seafarer', 'Seafarer'),
    ('Application Administrator', 'Application Administrator'),
    ('CBA/Wage Admin', 'CBA/Wage Admin'),
    ('CBA/Wage Admin', 'CBA_Wage_Admin'),
    ('Pre-sea Cadet', 'Pre-sea Cadet'),
    ('Pre-sea Cadet', 'Pre-sea_Cadet'),
    ('Master', 'Master'),
    ('Associate Group Head', 'Associate Group Head'),
    ('Associate Group Head', 'Associate_Group_Head'),
    ('Vessel Onboarding Approver', 'Vessel Onboarding Approver'),
    ('Vessel Onboarding Approver', 'Vessel_Onboarding_Approver'),
    ('Vessel Onboarding Team', 'Vessel Onboarding Team'),
    ('Vessel Onboarding Team', 'Vessel_Onboarding_Team'),
    ('Ship Management Team', 'Ship Management Team'),
    ('Ship Management Team', 'Ship_Management_Team'),
    ('Master Data Management Team', 'Master Data Management Team'),
    ('Master Data Management Team', 'Master_Data_Management_Team'),
    ('VP Master Admin', 'VP Master Admin'),
    ('VP Master Admin', 'VP_Master_Admin'),
    ('Vessel Master', 'Vessel Master'),
    ('Application Administrator', 'SynergyIdentityAdminAdministrator')
) AS t(target_role_name, source_role_name);
```

### 8. User Type ID Mapping
**Purpose**: Resolve `user_type_id` per legacy user (ServiceType, tenant, allocated company, fallback role, default)
**Output columns**: `source_user_id, user_type_id`

```sql
CREATE TEMP TABLE user_type_mapping AS
SELECT DISTINCT ON (legacy_data.id_text)
    legacy_data.id_text AS source_user_id,
    CASE

        WHEN fallback_utm.user_type_id IS NOT NULL THEN fallback_utm.user_type_id

        WHEN excluded_no_role.user_id_text IS NOT NULL AND (SELECT user_type_id FROM default_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM default_user_type LIMIT 1)

        WHEN ust.service_type_id = (SELECT recruitment_id FROM service_type_ids)
             AND (SELECT user_type_id FROM crewing_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM crewing_user_type LIMIT 1)
        WHEN ust.service_type_id = (SELECT technical_id FROM service_type_ids)
             AND (SELECT user_type_id FROM technical_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM technical_user_type LIMIT 1)

        WHEN ust.user_id_text IS NULL AND ucm.company_tenant_id = 2
        THEN (SELECT user_type_id FROM manning_user_type LIMIT 1)
        WHEN ust.user_id_text IS NULL AND (SELECT user_type_id FROM crewing_user_type LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM crewing_user_type LIMIT 1)

        WHEN allocated_non_manning.user_id_text IS NOT NULL THEN (SELECT user_type_id FROM crewing_user_type LIMIT 1)
        WHEN allocated_manning_only.user_id_text IS NOT NULL THEN (SELECT user_type_id FROM manning_user_type LIMIT 1)

        WHEN ucm.company_tenant_id IN (1, 3) THEN (SELECT user_type_id FROM crew_user_type LIMIT 1)
        WHEN ucm.company_tenant_id = 2 THEN (SELECT user_type_id FROM manning_user_type LIMIT 1)
        WHEN ucm.company_tenant_id = 4 THEN (SELECT user_type_id FROM ext_vendor_user_type LIMIT 1)

        ELSE (SELECT user_type_id FROM crew_user_type LIMIT 1)
    END AS user_type_id
FROM legacy_users legacy_data
LEFT JOIN fallback_user_type_from_role fallback_utm ON fallback_utm.user_id_text = legacy_data.id_text
LEFT JOIN users_excluded_no_mapped_role excluded_no_role ON excluded_no_role.user_id_text = legacy_data.id_text
LEFT JOIN user_service_type_mapping ust ON ust.user_id_text = legacy_data.id_text
LEFT JOIN user_company_id_mapping ucm ON ucm.source_user_id = legacy_data.id_text
LEFT JOIN users_with_allocated_company_non_manning allocated_non_manning ON allocated_non_manning.user_id_text = legacy_data.id_text
LEFT JOIN users_with_allocated_company_manning_only allocated_manning_only ON allocated_manning_only.user_id_text = legacy_data.id_text;
```

### 9. User Allocated Company ID Mapping
**Output columns**: `data.user_id_text, data.company_id_text, data.company_normalized_name, data.company_name, data.company_tenant_id`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_allocated_company_id_mapping AS
WITH user_allocated_company_source AS (
    SELECT
        data.user_id_text,
        data.company_id_text,
        data.company_normalized_name,
        data.company_name,
        data.company_tenant_id
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                uac."UserId"::text AS user_id_text,
                uac."CompanyId"::text AS company_id_text,
                c."NormalizedName" AS company_normalized_name,
                c."Name" AS company_name,
                c."TenantId" AS company_tenant_id
            FROM public."UserAllocatedCompany" uac
            INNER JOIN public."Company" c ON c."Id" = uac."CompanyId"
            WHERE uac."UserId" IS NOT NULL
              AND uac."CompanyId" IS NOT NULL
              AND c."NormalizedName" IS NOT NULL
              AND TRIM(c."NormalizedName") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        company_id_text text,
        company_normalized_name text,
        company_name text,
        company_tenant_id integer
    )
)
SELECT
    uacs.user_id_text AS source_user_id,
    uacs.company_id_text AS source_company_id,
    target_companies.id AS target_company_id,
    uacs.company_tenant_id,
    uacs.company_name AS source_company_name,
    CASE
        WHEN uacs.company_tenant_id = 2 THEN target_agents.id
        ELSE NULL::uuid
    END AS agent_id
FROM user_allocated_company_source uacs
LEFT JOIN public.companies target_companies
  ON UPPER(TRIM(target_companies.name)) = UPPER(TRIM(uacs.company_normalized_name))
LEFT JOIN public.agents target_agents
  ON uacs.company_tenant_id = 2
  AND UPPER(TRIM(target_agents.name)) = UPPER(TRIM(uacs.company_name))
WHERE


    (uacs.company_tenant_id = 2 AND target_agents.id IS NOT NULL)
    OR (COALESCE(uacs.company_tenant_id, -1) <> 2 AND target_companies.id IS NOT NULL);
```

### 10. User Department ID Mapping
**Purpose**: UserDepartment → target department by name
**Output columns**: `data.user_id_text, data.department_name`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_department_id_mapping AS
WITH user_department_source AS (
    SELECT
        data.user_id_text,
        data.department_name
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                ud."UserId"::text AS user_id_text,
                d."Name" AS department_name
            FROM public."UserDepartment" ud
            INNER JOIN public."Department" d ON d."Id" = ud."DepartmentId"
            WHERE ud."UserId" IS NOT NULL
              AND ud."DepartmentId" IS NOT NULL
              AND d."Name" IS NOT NULL
              AND TRIM(d."Name") <> ''
    $dblink_query$) AS data(
        user_id_text text,
        department_name text
    )
)
SELECT DISTINCT ON (uds.user_id_text)
    uds.user_id_text AS source_user_id,
    target_departments.id AS target_department_id
FROM user_department_source uds
JOIN public.departments target_departments
  ON UPPER(TRIM(target_departments.name)) = UPPER(TRIM(uds.department_name))
ORDER BY uds.user_id_text, target_departments.created_at;
```

### 11. User Designation ID Mapping
**Output columns**: `data.user_id_text, data.designation_id_text`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE user_designation_id_mapping AS
WITH user_designation_source AS (
    SELECT
        data.user_id_text,
        data.designation_id_text
    FROM dblink('synergy_identity_shore_prod', $dblink_query$
            SELECT
                ud."UserId"::text AS user_id_text,
                ud."DesignationId"::text AS designation_id_text
            FROM public."UserDesignation" ud
            WHERE ud."UserId" IS NOT NULL
              AND ud."DesignationId" IS NOT NULL
    $dblink_query$) AS data(
        user_id_text text,
        designation_id_text text
    )
)
SELECT DISTINCT ON (uds.user_id_text)
    uds.user_id_text AS source_user_id,
    des_map.target_id AS target_designation_id
FROM user_designation_source uds
JOIN designations_id_mapping des_map ON des_map.source_id = uds.designation_id_text
JOIN public.designations target_designations ON target_designations.id = des_map.target_id
ORDER BY uds.user_id_text, target_designations.created_at;
```

### 12. Users ID Mapping
**Purpose**: Legacy `Users.Id` → target `users.id` after users INSERT
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `Users` → `users` (source_db=`synergy_identity_shore_prod`)

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT source_id, target_id
FROM migration.table_mappings
WHERE source_db = 'synergy_identity_shore_prod'
  AND source_schema = 'public'
  AND source_table = 'Users'
  AND target_db = current_database()::text
  AND target_table = 'users';
```

### 13. Source User Roles (legacy UserRoles + Roles)
**Output columns**: `user_id_text, role_id_text, role_name, role_normalized_name`
**dblink**: `synergy_identity_shore_prod`

Feeds `shore_legacy_role_target_resolution` and fallback role assignment blocks.

### 14. Shore Legacy Role Target Resolution
**Output columns**: `user_id_text, role_id_text, role_id, role_code`

Maps legacy role **names** to `public.roles.id` (not direct `RoleId` UUID copy). Prefers roles where `roles.user_type_id` matches `user_type_mapping.user_type_id`; uses `fallback_role_mapping` when legacy and target role names differ.

### 15. Default Profile Company Resolved
**Output columns**: `source_user_id, target_company_id, company_tenant_id, agent_id`

`COALESCE(UserCompany mapping, first UserAllocatedCompany row)` for default profile `company_id` / `external_company_id`.

### 16. Master Nationality Lookups
**Output columns**: `norm_key, nationality_id`
**dblink**: `smac_master_migration`

Name match first (`smac_master_nationality_by_name`), then code (`smac_master_nationality_by_code`) for `users.nationality_id`.

Full migration context: `04-migration-scripts/idp/users_migration.sql`

## Validation

- Run `05-validation/idp/users_validation.sql` if available
- Run `06-rollback/idp/users_rollback.sql` if rollback is required

## Document Status

Updated to document all 8 INSERT blocks: `users`, `user_profiles` (default + `UserAllocatedCompany`), `user_roles` (×3), and `migration.table_mappings` (×2). Includes `user_roles` role-name resolution via `fallback_role_mapping` and profile-level `user_id` FK semantics.
