# Table Mapping: "Users" → users

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: users
- **Source Script**: `04-migration-scripts/idp/users_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Users"`
- **New Path**: `smac_idp_dev.public.users`

## Business Key

- **Composite Key**: (`username`, `email`)
- **Source (orchestration)**: Users (`Users` → `users`)

## Migration Notes

- Migrates Shore users from synergy_identity_shore_prod database.

## Special Considerations

- Orchestration dependencies: `roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 12

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `user_service_type_mapping` | FK lookup | `ust.user_id_text`, `ust.service_type_id` | - | `synergy_identity_shore_prod` |
| `companies_id_mapping` | FK lookup | `source_id`, `target_id` | `synergy_master.public.ship_management_companies` → `?.?.companies` | `smac_master_migration` |
| `departments_id_mapping` | FK lookup | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Department` → `?.?.departments` | `smac_master_migration` |
| `ranks_id_mapping` | FK lookup | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Ranks` → `?.?.ranks` | - |
| `designations_id_mapping` | FK lookup | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Designation` → `?.?.designations` | `smac_master_migration` |
| `user_company_id_mapping` | FK lookup | `data.user_id_text`, `data.company_normalized_name`, `data.company_name`, `data.company_tenant_id` | - | `synergy_identity_shore_prod` |
| `fallback_role_mapping` | FK lookup | `target_role_name`, `source_role_name` | - | - |
| `user_type_mapping` | ------------------------------------------------------------------- | `source_user_id`, `user_type_id` | - | - |
| `user_allocated_company_id_mapping` | FK lookup | `data.user_id_text`, `data.company_id_text`, `data.company_normalized_name`, `data.company_name`, `data.company_tenant_id` | - | `synergy_identity_shore_prod` |
| `user_department_id_mapping` | Create user_type mapping based on ServiceType, Company TenantId, UserAllocatedCompany, fallback role, and default | `data.user_id_text`, `data.department_name` | - | `synergy_identity_shore_prod` |
| `user_designation_id_mapping` | FK lookup | `data.user_id_text`, `data.designation_id_text` | - | `synergy_identity_shore_prod` |
| `users_id_mapping` | Company for default profile (is_default_profile = true): UserCompany mapping when present; | `source_id`, `target_id` | `synergy_identity_shore_prod.public.Users` → `?.?.users` | - |

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

- **Purpose**: -------------------------------------------------------------------
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

- **Purpose**: Create user_type mapping based on ServiceType, Company TenantId, UserAllocatedCompany, fallback role, and default
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

### `users_id_mapping`

- **Purpose**: Company for default profile (is_default_profile = true): UserCompany mapping when present;
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id_text, id_uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_identity_shore_prod'::varchar(100), 'public'::varchar(100), 'Users'::varchar(100), legacy_data.id_text, current_database()::text::varchar(1... |
| 2 | derived | - | company_id | - | dpc.target_company_id AS company_id | dpc.target_company_id |
| 3 | derived | - | is_default_profile | - | true AS is_default_profile | true |
| 4 | - | - | vessel_id | - | NULL | NULL::uuid |
| 5 | derived | - | department_id | - | user_department_map.target_department_id AS department_id | user_department_map.target_department_id |
| 6 | derived | - | designation_id | - | user_designation_map.target_designation_id AS designation_id | user_designation_map.target_designation_id |
| 7 | derived | - | rank_id | - | rank_map.target_id | rank_map.target_id |
| 8 | first_name | - | first_name | - | NULLIF(TRIM(COALESCE(legacy_data.first_name, '')), '') AS first_name | NULLIF(TRIM(COALESCE(legacy_data.first_name, '')), '') |
| 9 | last_name | - | last_name | - | NULLIF(TRIM(COALESCE(legacy_data.last_name, '')), '') AS last_name | NULLIF(TRIM(COALESCE(legacy_data.last_name, '')), '') |
| 10 | - | - | employee_id | - | NULL | NULL::varchar(50) |
| 11 | email | - | email | - | NULLIF(TRIM(COALESCE(legacy_data.email, '')), '') AS email | NULLIF(TRIM(COALESCE(legacy_data.email, '')), '') |
| 12 | phone_number | - | phone_number | - | NULLIF(TRIM(COALESCE(legacy_data.phone_number, '')), '') AS phone_number | NULLIF(TRIM(COALESCE(legacy_data.phone_number, '')), '') |
| 13 | derived | - | user_type | - | COALESCE(utm.user_type_id, (SELECT user_type_id FROM crew_user_type LIMIT 1)) AS user_type | COALESCE(utm.user_type_id, (SELECT user_type_id FROM crew_user_type LIMIT 1)) |
| 14 | - | - | profile_picture | - | NULL | NULL::varchar(255) |
| 15 | derived | - | user_id | - | user_map.target_id AS user_id | user_map.target_id |
| 16 | - | - | attributes | - | NULL | NULL::jsonb |
| 17 | - | - | mfa_config | - | NULL | NULL::jsonb |
| 18 | - | - | archived_at | - | NULL | NULL::timestamp |
| 19 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 20 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 21 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 22 | id_text | - | audit_info | - | jsonb_build_object( 'legacy_user_id', legacy_data.id_text, 'migration_source', 'synergy_identity_shore_prod', 'migrated_at', NOW() ) AS audit_info | jsonb_build_object( 'legacy_user_id', legacy_data.id_text, 'migration_source', 'synergy_identity_shore_prod', 'migrated_at', NOW() ) |
| 23 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 24 | - | - | cdc_number | - | NULL | NULL::varchar(100) |
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
**Purpose**: -------------------------------------------------------------------
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
**Purpose**: Create user_type mapping based on ServiceType, Company TenantId, UserAllocatedCompany, fallback role, and default
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
**Purpose**: Company for default profile (is_default_profile = true): UserCompany mapping when present;
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

Full migration context: `04-migration-scripts/idp/users_migration.sql`

## Validation

- Run `05-validation/idp/users_validation.sql` if available
- Run `06-rollback/idp/users_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
