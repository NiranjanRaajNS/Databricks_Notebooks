# Table Mapping: ship_management_companies, mlc_master → companies

## Overview
- **Legacy Database**: synergy_master, synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies, mlc_master
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: companies
- **Source Script**: `04-migration-scripts/master/companies_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`, `synergy_vessel.public.mlc_master`
- **New Path**: `smac_master_migration.public.companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Dual source merged via `UNION ALL`: `synergy_master.public.ship_management_companies` + `synergy_vessel.public.mlc_master`
- `ship_management_companies`: SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `mlc_master`: no `identifier` column — idempotent UUID from bigint `id` (`p_target_id = NULL`)
- `code` from `group_companies.group_company_code` (LEFT JOIN on `ship_management_company_id`); fallback: `UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_'))`, then `'COMPANY_' || id`
- `mlc_master.ship_owner_entity` mapped to SMAC `name`
- `company_type_id` looked up from `public.company_types` where `LOWER(TRIM(name)) = 'ship management companies'`
- `synergy_company` → `is_inhouse_company`; `mlc_master` defaults to `false`
- `mlc_master` records tagged with `['mlc_ship_owner']` in `tags`
- `status`: `deleted_at IS NOT NULL` → Deleted (3) for both sources; additionally for `mlc_master`, `is_active = false` (derived from `NOT isdeleted`) → Deleted (3); `ship_management_companies.is_active` is **not** used for status
- Deduplication: `ship_management_companies` — `DISTINCT ON (identifier/id)` then `ROW_NUMBER()` by source identity; `mlc_master` — skipped when normalized name already exists in `ship_management_companies` for same active/deleted state
- Pre-migration duplicate UUID check on `ship_management_companies.identifier` only
- `service_type_mapping` created for prerequisite validation only — not used in INSERT column mapping

## Special Considerations

- Script performs `TRUNCATE TABLE public.companies CASCADE` before insert (full table reload)
- `mlc_master` migration is optional — skipped gracefully if table unavailable in `synergy_vessel`
- Requires `service_types` and `company_types` tables as prerequisites
- Orchestration dependencies: `service_types`, `company_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script.

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `service_type_mapping` | Prerequisite validation only (not used in INSERT) | `name`, `service_type_id` | - | - |

### `service_type_mapping`

- **Purpose**: Prerequisite validation only (not used in INSERT)
- **Output columns**: name, service_type_id

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    name,
    id AS service_type_id
FROM public.service_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — dynamic `source_db`/`source_table`; source_id = `id::text`; `p_target_id = identifier` | `ship_management_companies`: preserves `identifier`; `mlc_master`: `identifier` is NULL — idempotent UUID from bigint `id` |
| 2 | `group_company_code`, `name`, `id` | text, bigint | `code` | text | `COALESCE(NULLIF(TRIM(group_company_code), ''), UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_')), 'COMPANY_' \|\| id)` | `group_company_code` from `group_companies` join (`ship_management_companies` only); `mlc_master` uses name/id fallback; NOT NULL in SMAC |
| 3 | `name`, `ship_owner_entity`, `id` | text, bigint | `name` | text | `COALESCE(NULLIF(TRIM(name), ''), 'COMPANY_' \|\| id)` | `ship_management_companies.name` direct; `mlc_master.ship_owner_entity` aliased as `name`; NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | No equivalent in SAC sources; not populated |
| 5 | — | — | `company_type_id` | uuid | Subquery: `company_types` where `LOWER(TRIM(name)) = 'ship management companies'` LIMIT 1 | Lookup: `public.company_types`; NULL when type not found |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | No equivalent in SAC sources; not populated |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | `synergy_company` | boolean | `is_inhouse_company` | boolean | `COALESCE(synergy_company, false)` | SAC flag renamed; `mlc_master` hardcoded to `false` |
| 10 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 11 | `source_table` (derived) | text | `tags` | text[] | `ARRAY['mlc_ship_owner']` when `source_table = 'mlc_master'`; else `NULL` | Derived tag to distinguish `mlc_master` records; not a SAC column |
| 12 | `deleted_at`, `is_active`, `isdeleted` | timestamp without time zone, boolean | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); `mlc_master` + `is_active = false` (`NOT isdeleted`) → Deleted (3); else Active (0) | `ship_management_companies.is_active` not used; `mlc_master.isdeleted` inverted to derive `is_active` |
| 13 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 14 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 15 | `imo_number` | text | `imo_number` | text | `NULLIF(TRIM(imo_number), '')` | From `ship_management_companies` only; `mlc_master` has no IMO — NULL |
| 16 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; `mlc_master` pre-coalesced in dblink SELECT; NOT NULL in SMAC |
| 17 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 18 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 19 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC sources; not populated |
| 20 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | `mlc_master` has no `created_by_name`/`updated_by_name`; no `legacy_id` when identifier preserved as `id` |

**SMAC columns not migrated:** `parent_id`, `description`, `archived_at` — no source equivalent or hardcoded NULL.

**SAC columns not migrated (`ship_management_companies`):** `contact_number`, `is_active`, `doc_company`, `recruitment_company`, `employer_agent`, `address` — not mapped to SMAC `companies` columns (used by related migrations such as `company_details`, `company_services`).

**SAC columns not migrated (`mlc_master`):** `ship_owner_address` (aliased as `address` internally), `isdeleted` (used only to derive `is_active`/`status`).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.company_types`
- `public.service_types`

## Data Transformation Rules

### 1. Dual-Source UNION and Deduplication

Sources are combined in `legacy_union` CTE, then deduplicated in `ranked` CTE:

- **`ship_management_companies`**: `DISTINCT ON (identifier/id)` within source; all rows retained via `ROW_NUMBER()` partitioned by identifier/id
- **`mlc_master`**: excluded when normalized name (`UPPER(REGEXP_REPLACE(TRIM(name), '\s+', '', 'g'))`) already exists in `ship_management_companies` for the same active/deleted state (`deleted_at IS NULL`)

### 2. Group Company Code Lookup

```sql
LEFT JOIN dblink('synergy_master',
    'SELECT ship_management_company_id, group_company_code FROM public.group_companies'
) AS group_companies ON group_companies.ship_management_company_id = legacy_data.id
```

### 3. Service Type ID Mapping (Prerequisite Validation Only)

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT name, id AS service_type_id FROM public.service_types;
```

Full migration context: `04-migration-scripts/master/companies_migration.sql`

## Validation

- Run `05-validation/master/companies_validation.sql` if available
- Run `06-rollback/master/companies_rollback.sql` if rollback is required

## Document Status

Reviewed against `companies_migration.sql`. Dual-source UNION with cross-source name deduplication.
