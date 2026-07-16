# Table Mapping: ship_management_companies → company_services

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: company_services
- **Source Script**: `04-migration-scripts/master/company_services_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`
- **New Path**: `smac_master_migration.public.company_services`

## Business Key

- **Composite Key**: (`company_id`, `service_type_id`)
- **Source (orchestration)**: Company Services (`ship_management_companies` → `company_services`)

## Migration Notes

- UNION of four INSERT branches from `ship_management_companies` boolean flags
- Composite source_id: `id|doc_company`, `id|recruitment_company`, etc.
- `service_type_id` from `service_types` (Technical/Crewing/Accounting/MLC)
- `is_global` when company code = `'SMRSPL'`

## Special Considerations

- Script performs `TRUNCATE TABLE public.company_services` before insert (full table reload).
- Orchestration dependencies: `companies`, `service_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | FK lookup | `legacy_company_id`, `company_id` | `?.?.ship_management_companies` → `?.?.companies` | - |
| `service_type_mapping` | FK lookup | `normalized_name`, `service_type_id` | - | - |

### `company_id_mapping`

- **Output columns**: legacy_company_id, company_id
- **migration.table_mappings**: source_table=ship_management_companies, target_table=companies

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_db = current_database();
```

### `service_type_mapping`

- **Output columns**: normalized_name, service_type_id

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_name,
    id AS service_type_id
FROM public.service_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, doc_company/recruitment_company/employer_agent/is_active` | bigint, boolean | `id` | uuid | `migration.resolve_target_id()` — composite source_id `id|flag_name`; `p_target_id = NULL` | One row per service flag |
| 2 | `id` | bigint | `company_id` | uuid | Join `companies` on ship_management_company id→identifier | FK lookup |
| 3 | `—` | — | `service_type_id` | uuid | From `service_types` lookup per flag type | FK: service_types |
| 4 | `created_at` | timestamp without time zone | `start_date` | date | `created_at::date` | Service start date |
| 5 | `—` | — | `end_date` | date | `NULL` | No end date in SAC |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 12 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 13 | `created_by_id, updated_by_id, created_by_name, updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 15 | `doc_company/recruitment_company/employer_agent` | boolean | `tags` | text[] | Service flag name as tag |  |
| 16 | `companies.code` | text | `is_global` | boolean | `true` when company code = `'SMRSPL'` | Business rule |
| 17 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 18 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 19 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |

**SAC columns not migrated:** Most company columns beyond boolean flags and audit fields.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`
- `public.service_types`
- `service_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Output columns**: `legacy_company_id, company_id`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_db = current_database();
```

### 2. Service Type ID Mapping
**Output columns**: `normalized_name, service_type_id`

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_name,
    id AS service_type_id
FROM public.service_types;
```

Full migration context: `04-migration-scripts/master/company_services_migration.sql`

## Validation

- Run `05-validation/master/company_services_validation.sql` if available
- Run `06-rollback/master/company_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
