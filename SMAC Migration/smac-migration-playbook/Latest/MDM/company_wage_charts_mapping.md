# Table Mapping: wage_charts → company_wage_charts

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_charts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_charts
- **Source Script**: `04-migration-scripts/master/company_wage_charts_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_charts`
- **New Path**: `smac_master_migration.crewing.company_wage_charts`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Charts (`wage_charts` → `company_wage_charts`)

## Migration Notes

- Source `id` is bigint — `migration.resolve_target_id()` with `p_target_id = NULL`
- `company_wage_group_id` from `vessel_group_id` via mapping
- `is_all_nationalities` from migrated `cbas` by `cba_code`
- `currency_id` defaults to USD
- Filter: `type=0`, name non-empty

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Only migrate rows where type = 0
- Script performs `TRUNCATE TABLE crewing.company_wage_charts` before insert (full table reload).
- Orchestration dependencies: `company_wage_groups`, `cbas`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_groups_id_mapping` | Check if target table has exist | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `currencies_id_mapping` | Check if any mappings already | `legacy_id`, `new_id`, `currency_code` | `migration.table_mappings` (see SQL) | - |

### `company_wage_groups_id_mapping`

- **Purpose**: Check if target table has exist
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_groups

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### `currencies_id_mapping`

- **Purpose**: Check if any mappings already
- **Output columns**: legacy_id, new_id, currency_code
- **migration.table_mappings**: target_table=currencies

```sql
CREATE TEMP TABLE currencies_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.code as currency_code
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 4 | `—` | — | `description` | text | `NULL` |  |
| 5 | `vessel_group_id` | bigint | `company_wage_group_id` | uuid | Map via `company_wage_groups_id_mapping` | FK lookup |
| 6 | `effective_date` | date | `effective_date` | date | Direct copy |  |
| 7 | `cba_code` | text | `is_all_nationalities` | boolean | From migrated `cbas.is_all_nationalities` matched by `cba_code` | Cross-db lookup |
| 8 | `—` | — | `currency_id` | uuid | `COALESCE` to USD currency id | Hardcoded USD default |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `isdeleted, deleted_at` | boolean, timestamp without time zone | `status` | integer | `isdeleted` or `deleted_at` → Deleted (3); else Active (0) |  |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 16 | `created_by_id, updated_by_id, created_by_name, updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 17 | `—` | — | `level` | numeric | Hardcoded `0` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cbas`
- `company_wage_groups`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Groups ID Mapping
**Purpose**: Check if target table has exist
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_groups'`

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### 2. Currencies ID Mapping
**Purpose**: Check if any mappings already
**Output columns**: `legacy_id, new_id, currency_code`
**migration.table_mappings**: `target_table='currencies'`

```sql
CREATE TEMP TABLE currencies_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.code as currency_code
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_charts_migration.sql`

## Validation

- Run `05-validation/master/company_wage_charts_validation.sql` if available
- Run `06-rollback/master/company_wage_charts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
