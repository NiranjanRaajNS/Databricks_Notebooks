# Table Mapping: ship_management_companies → company_details

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: company_details
- **Source Script**: `04-migration-scripts/master/company_details_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`
- **New Path**: `smac_master_migration.public.company_details`

## Business Key

- **Business Key**: `company_id`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `company_details`)

## Migration Notes

- Source `id` is bigint — `migration.resolve_target_id()` with `p_target_id = NULL`
- `company_id` via join to `companies` by name
- `address` as JSONB from address/city/zipcode
- `tags` = `['doc_company']` when `doc_company = true`
- Filter: name non-empty; `DISTINCT ON (id)`

## Special Considerations

- Script performs `TRUNCATE TABLE public.company_details` before insert (full table reload).
- Orchestration dependencies: `companies`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | FK lookup | `legacy_name`, `company_id` | - | - |

### `company_id_mapping`

- **Output columns**: legacy_name, company_id

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    name as legacy_name,
    id as company_id
FROM public.companies;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `name` | text | `company_id` | uuid | Join `companies` on name match | FK lookup |
| 3 | `address, city, zipcode` | text, text, text | `address` | jsonb | `jsonb_build_object` from address, city, zipcode | Structured address |
| 4 | `—` | — | `country_id` | uuid | `NULL` | Not populated in script |
| 5 | `contact_number` | text | `phone_number` | text | Direct copy |  |
| 6 | `—` | — | `email` | text | `NULL` | No email in SAC |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `updated_by_id` | text | `version` | integer | From `updated_by_id` if numeric else `1` | Unusual version mapping |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 13 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 14 | `created_by_id, updated_by_id, created_by_name, updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 15 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 16 | `doc_company` | boolean | `tags` | text[] | `['doc_company']` when `doc_company = true`; else empty |  |
| 17 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 18 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 19 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |

**SAC columns not migrated:** `identifier`, `synergy_company`, `stamp_icon`, `service`, `recruitment_company`, `employer_agent`, `takeover_date`, `tenant`, `total_used_count`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Output columns**: `legacy_name, company_id`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    name as legacy_name,
    id as company_id
FROM public.companies;
```

Full migration context: `04-migration-scripts/master/company_details_migration.sql`

## Validation

- Run `05-validation/master/company_details_validation.sql` if available
- Run `06-rollback/master/company_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
