# Table Mapping: users_roles_patch → users_roles_patch

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: users_roles_patch
- **Source Script**: `04-migration-scripts/idp/users_roles_patch_migration.sql`


## Business Key

- **Business Key**: `ucs.user_id_text`
- **Source (orchestration)**: User Roles Patch (`UserRoles` → `user_roles`)

## Migration Notes

- Patch: apply role mapping to already-migrated users. Fetches roles from source, applies fallback mapping, inserts missing user_roles in target.

## Special Considerations

- Orchestration dependencies: `roles`, `users`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `user_service_type_mapping` | FK lookup | `ust.user_id_text`, `ust.service_type_id` | - | `synergy_identity_shore_prod` |
| `user_company_id_mapping` | FK lookup | `data.user_id_text`, `data.company_normalized_name`, `data.company_name`, `data.company_tenant_id` | - | `synergy_identity_shore_prod` |
| `users_with_allocated_company_non_manning` | Map user companies fro | `DISTINCT user_id_text` | - | `synergy_identity_shore_prod` |
| `fallback_role_mapping` | FK lookup | `target_role_name`, `source_role_name` | - | - |
| `user_type_mapping_patch` | FK lookup | `source_user_id`, `user_type_id` | - | - |

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

### `users_with_allocated_company_non_manning`

- **Purpose**: Map user companies fro
- **Output columns**: DISTINCT user_id_text
- **dblink connection**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE users_with_allocated_company_non_manning AS
SELECT DISTINCT user_id_text
FROM dblink('synergy_identity_shore_prod', $dblink_query$
    SELECT uac."UserId"::text AS user_id_text, c."TenantId" AS company_tenant_id
    FROM public."UserAllocatedCompany" uac
    INNER JOIN public."Company" c ON c."Id" = uac."CompanyId"
    WHERE uac."UserId" IS NOT NULL AND uac."CompanyId" IS NOT NULL
$dblink_query$) AS data(user_id_text text, company_tenant_id integer)
WHERE data.company_tenant_id IS NOT NULL AND data.company_tenant_id <> 2;
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

### `user_type_mapping_patch`

- **Output columns**: source_user_id, user_type_id

```sql
CREATE TEMP TABLE user_type_mapping_patch AS
SELECT DISTINCT ON (legacy_data.id_text)
    legacy_data.id_text AS source_user_id,
    CASE
        WHEN fallback_utm.user_type_id IS NOT NULL THEN fallback_utm.user_type_id
        WHEN excluded_no_role.user_id_text IS NOT NULL AND (SELECT user_type_id FROM default_user_type_patch LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM default_user_type_patch LIMIT 1)
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
        ...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() AS id | gen_random_uuid() |
| 2 | derived | - | user_id | - | picked.profile_id AS user_id | picked.profile_id |
| 3 | derived | - | role_id | - | picked.role_id | picked.role_id |
| 4 | - | - | assigned_by | - | NULL | NULL::uuid |
| 5 | derived | - | role_code | - | picked.role_code | picked.role_code |
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

### 2. User Company ID Mapping
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
    CASE WHEN ucs.company_tenant_id = 2 THEN 0 ELSE 1 END,
    COALESCE(target_companies.created_at, NOW());
```

### 3. Users With Allocated Company Non Manning ID Mapping
**Purpose**: Map user companies fro
**Output columns**: `DISTINCT user_id_text`
**dblink**: `synergy_identity_shore_prod`

```sql
CREATE TEMP TABLE users_with_allocated_company_non_manning AS
SELECT DISTINCT user_id_text
FROM dblink('synergy_identity_shore_prod', $dblink_query$
    SELECT uac."UserId"::text AS user_id_text, c."TenantId" AS company_tenant_id
    FROM public."UserAllocatedCompany" uac
    INNER JOIN public."Company" c ON c."Id" = uac."CompanyId"
    WHERE uac."UserId" IS NOT NULL AND uac."CompanyId" IS NOT NULL
$dblink_query$) AS data(user_id_text text, company_tenant_id integer)
WHERE data.company_tenant_id IS NOT NULL AND data.company_tenant_id <> 2;
```

### 4. Fallback Role ID Mapping
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

### 5. User Type Mapping Patch
**Output columns**: `source_user_id, user_type_id`

```sql
CREATE TEMP TABLE user_type_mapping_patch AS
SELECT DISTINCT ON (legacy_data.id_text)
    legacy_data.id_text AS source_user_id,
    CASE
        WHEN fallback_utm.user_type_id IS NOT NULL THEN fallback_utm.user_type_id
        WHEN excluded_no_role.user_id_text IS NOT NULL AND (SELECT user_type_id FROM default_user_type_patch LIMIT 1) IS NOT NULL
        THEN (SELECT user_type_id FROM default_user_type_patch LIMIT 1)
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
FROM legacy_ids_patch legacy_data
LEFT JOIN fallback_user_type_from_role fallback_utm ON fallback_utm.user_id_text = legacy_data.id_text
LEFT JOIN users_excluded_no_mapped_role excluded_no_role ON excluded_no_role.user_id_text = legacy_data.id_text
LEFT JOIN user_service_type_mapping ust ON ust.user_id_text = legacy_data.id_text
LEFT JOIN user_company_id_mapping ucm ON ucm.source_user_id = legacy_data.id_text
LEFT JOIN users_with_allocated_company_non_manning allocated_non_manning ON allocated_non_manning.user_id_text = legacy_data.id_text
LEFT JOIN users_with_allocated_company_manning_only allocated_manning_only ON allocated_manning_only.user_id_text = legacy_data.id_text;
```

Full migration context: `04-migration-scripts/idp/users_roles_patch_migration.sql`

## Validation

- Run `05-validation/idp/users_roles_patch_validation.sql` if available
- Run `06-rollback/idp/users_roles_patch_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
