# Table Mapping: fleet_master → fleets

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: fleet_master
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fleets
- **Source Script**: `04-migration-scripts/master/fleets_migration.sql`

- **Legacy Path**: `synergy_vessel.public.fleet_master`
- **New Path**: `smac_master_migration.vessel.fleets`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Fleets (`fleet_master` → `fleets`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `company_id` mapped via `company_id_mapping` (`ship_management_companies` → `companies`)
- `department_id` mapped via `fdl_department_id_mapping` → `fdl_department_id`
- `fleet_type_id` derived from name: contains WET → WET type; contains DRY → DRY type via `fleet_type_mapping`
- `prefix` built from company code, department code, and fleet type code; stripped from `name` when present
- `status` derived from `deleted_at` + `status` text (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Filter: `name IS NOT NULL` and `TRIM(name) <> ''`
- All records migrated including deleted (`deleted_at` preserved)

## Special Considerations

- `DISTINCT ON (id)` prevents duplicates when multiple FK mappings exist
- Script performs `TRUNCATE TABLE vessel.fleets` before insert (full table reload)
- Orchestration dependencies: `companies`, `fdl_departments`, `fleet_types` (seed data)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | Check for duplicate UUIDs in source table | `legacy_company_id`, `new_company_id`, `company_code` | `?.?.ship_management_companies` → `?.public.companies` | - |
| `fdl_department_id_mapping` | FK lookup | `legacy_department_id`, `new_fdl_department_id`, `department_code` | `migration.table_mappings` (see SQL) | - |
| `fleet_type_mapping` | FK lookup | `fleet_type_code`, `fleet_type_id` | - | - |

### `company_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_company_id, new_company_id, company_code
- **migration.table_mappings**: source_table=ship_management_companies, target_schema=public, target_table=companies

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint as legacy_company_id,
    tm.target_id::uuid as new_company_id,
    c.code as company_code
FROM migration.table_mappings tm
LEFT JOIN public.companies c ON c.id = tm.target_id::uuid
WHERE tm.target_table = 'companies'
  AND tm.target_schema = 'public'
  AND tm.source_table ='ship_management_companies'
  AND tm.target_db = COALESCE(:'TARGET_DB', current_database())
ORDER BY tm.source_id::bigint, tm.target_id;
```

### `fdl_department_id_mapping`

- **Output columns**: legacy_department_id, new_fdl_department_id, department_code
- **migration.table_mappings**: target_table=fdl_departments

```sql
CREATE TEMP TABLE fdl_department_id_mapping AS
SELECT DISTINCT ON (tm.source_id::integer)
    tm.source_id::integer as legacy_department_id,
    tm.target_id::uuid as new_fdl_department_id,
    d.code as department_code
FROM migration.table_mappings tm
LEFT JOIN vessel.fdl_departments d ON d.id = tm.target_id::uuid
WHERE tm.target_table = 'fdl_departments'
  AND tm.target_db = current_database()
ORDER BY tm.source_id::integer, tm.target_id;
```

### `fleet_type_mapping`

- **Output columns**: fleet_type_code, fleet_type_id

```sql
CREATE TEMP TABLE fleet_type_mapping AS
SELECT
    code as fleet_type_code,
    id as fleet_type_id
FROM vessel.fleet_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `id` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), id::text)` | Generated business code; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | Strip calculated `prefix` from start of name; truncate to 255 chars; else `TRIM(name)` | Prefix removed when name starts with company-dept-type prefix |
| 4 | — | — | `description` | text | Hardcoded NULL | No equivalent in SAC source |
| 5 | `company_id` | bigint | `company_id` | uuid | Map via `company_id_mapping` | Lookup: `migration.table_mappings` (`ship_management_companies` → `companies`) |
| 6 | `department_id` | integer | `fdl_department_id` | uuid | Map via `fdl_department_id_mapping` | Lookup: `migration.table_mappings` (`fdl_departments`) |
| 7 | `name` | text | `fleet_type_id` | uuid | WET/DRY inferred from name; lookup `fleet_type_mapping` by code | NULL when name contains neither WET nor DRY |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 10 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 14 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 15 | — | — | `level` | numeric | Hardcoded NULL | Not in SAC source |
| 16 | `company_id`, `department_id`, `name` | bigint, integer, text | `prefix` | text | Concatenate company code, department code, fleet type code with dashes | Derived from lookup codes and WET/DRY detection |
| 17 | — | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 18 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 19 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 20 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 21 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; `ApprovedAt` and `ApprovalNotes` from SAC `audit_info` | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |

**SAC columns not migrated:** `manager_user_id`, `group_head_user_id` — present in source but not inserted into SMAC.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `fdl_departments`
- `vessel.fdl_departments`
- `vessel.fleet_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_company_id, new_company_id, company_code`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint as legacy_company_id,
    tm.target_id::uuid as new_company_id,
    c.code as company_code
FROM migration.table_mappings tm
LEFT JOIN public.companies c ON c.id = tm.target_id::uuid
WHERE tm.target_table = 'companies'
  AND tm.target_schema = 'public'
  AND tm.source_table ='ship_management_companies'
  AND tm.target_db = COALESCE(:'TARGET_DB', current_database())
ORDER BY tm.source_id::bigint, tm.target_id;
```

### 2. Fdl Department ID Mapping
**Output columns**: `legacy_department_id, new_fdl_department_id, department_code`
**migration.table_mappings**: `target_table='fdl_departments'`

```sql
CREATE TEMP TABLE fdl_department_id_mapping AS
SELECT DISTINCT ON (tm.source_id::integer)
    tm.source_id::integer as legacy_department_id,
    tm.target_id::uuid as new_fdl_department_id,
    d.code as department_code
FROM migration.table_mappings tm
LEFT JOIN vessel.fdl_departments d ON d.id = tm.target_id::uuid
WHERE tm.target_table = 'fdl_departments'
  AND tm.target_db = current_database()
ORDER BY tm.source_id::integer, tm.target_id;
```

### 3. Fleet Type ID Mapping
**Output columns**: `fleet_type_code, fleet_type_id`

```sql
CREATE TEMP TABLE fleet_type_mapping AS
SELECT
    code as fleet_type_code,
    id as fleet_type_id
FROM vessel.fleet_types;
```

Full migration context: `04-migration-scripts/master/fleets_migration.sql`

## Validation

- Run `05-validation/master/fleets_validation.sql` if available
- Run `06-rollback/master/fleets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
