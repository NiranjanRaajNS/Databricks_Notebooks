# Table Mapping: additional_wages → company_wage_scale_allowance_amount

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: additional_wages
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_scale_allowance_amount
- **Source Script**: `04-migration-scripts/master/company_wage_scale_allowance_amount_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.additional_wages`
- **New Path**: `smac_master_migration.crewing.company_wage_scale_allowance_amount`

## Business Key

- **Composite Key**: (`company_wage_scale_allowance_id`, `wage_component_id`)
- **Source (orchestration)**: Company Wage Scale Allowance Amount (`additional_wages` → `company_wage_scale_allowance_amount`)

## Migration Notes

- From `additional_wages`; 1:1 with allowance via mapping
- `wage_component_id` via `wage_components` mapping; zero-UUID fallback
- Filter: INNER JOIN allowance mapping required

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_scale_allowance_amount` before insert (full table reload).
- Orchestration dependencies: `company_wage_scale_allowances`, `wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_scale_allowances_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `company_wage_scale_allowances_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_scale_allowances

```sql
CREATE TEMP TABLE company_wage_scale_allowances_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scale_allowances'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `id` | bigint | `company_wage_scale_allowance_id` | uuid | 1:1 via `company_wage_scale_allowances` mapping | FK lookup |
| 3 | `wage_component_uuid` | uuid | `wage_component_id` | uuid | Map via `wage_components_id_mapping`; zero-UUID fallback | FK lookup |
| 4 | `min_experience` | integer | `range_start` | integer | Direct copy |  |
| 5 | `max_experience` | integer | `range_end` | integer | Direct copy |  |
| 6 | `amount` | numeric | `pay` | numeric | Direct copy |  |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `isdeleted` | boolean | `status` | integer | `isdeleted` → Deleted (3); else Active (0) |  |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 16 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Uses status from isdeleted |
| 17 | `created_by_id, updated_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 18 | `—` | — | `tags` | text[] | `NULL` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_scale_allowances`
- `crewing.company_wage_scale_allowances`
- `crewing.wage_components`
- `wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Scale Allowances ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_scale_allowances'`

```sql
CREATE TEMP TABLE company_wage_scale_allowances_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scale_allowances'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_scale_allowance_amount_migration.sql`

## Validation

- Run `05-validation/master/company_wage_scale_allowance_amount_validation.sql` if available
- Run `06-rollback/master/company_wage_scale_allowance_amount_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
