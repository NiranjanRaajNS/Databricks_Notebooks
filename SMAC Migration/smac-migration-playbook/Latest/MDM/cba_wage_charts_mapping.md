# Table Mapping: cba_wage_chart → cba_wage_charts

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_chart
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_charts
- **Source Script**: `04-migration-scripts/master/cba_wage_charts_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_chart`
- **New Path**: `smac_master_migration.crewing.cba_wage_charts`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cba Wage Chart (`cba_wage_chart` → `cba_wage_charts`)

## Migration Notes

- SAC `id` (uuid) preserved; `cba_id` mapped via `cbas_id_mapping`
- `code` from `UPPER(REPLACE(TRIM(name), ' ', '_'))`
- Filter: name non-empty; `cba_mapping.new_id IS NOT NULL`

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_charts` before insert (full table reload).
- Orchestration dependencies: `cbas`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | Check if | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cbas_id_mapping`

- **Purpose**: Check if
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `name` | text | `code` | text | `UPPER(REPLACE(TRIM(name), ' ', '_'))` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 4 | `cba_id` | bigint | `cba_id` | uuid | Map via `cbas_id_mapping` | FK: `cbas` |
| 5 | `include_superior_certificate` | boolean | `include_superior_certificate` | boolean | Direct copy |  |
| 6 | `effective_date` | date | `effective_date` | date | Direct copy |  |
| 7 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 8 | `—` | — | `description` | text | `NULL` | No description in SAC |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 16 | `created_by, updated_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |

**SAC columns not migrated:** `created_by`, `updated_by` — used in audit_info only.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cbas`
- `crewing.cbas`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cbas ID Mapping
**Purpose**: Check if
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cbas'`

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/master/cba_wage_charts_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_charts_validation.sql` if available
- Run `06-rollback/master/cba_wage_charts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
