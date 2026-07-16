# Table Mapping: cba_wage_chart_wage_components → cba_wage_chart_wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_chart_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_chart_wage_components
- **Source Script**: `04-migration-scripts/master/cba_wage_chart_wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_chart_wage_components`
- **New Path**: `smac_master_migration.crewing.cba_wage_chart_wage_components`

## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `wage_component_id`)
- **Source (orchestration)**: CBA Wage Chart Wage Components (`cba_wage_chart_wage_components` → `cba_wage_chart_wage_components`)

## Migration Notes

- SAC `id` (uuid) preserved
- FK lookups with zero-UUID fallbacks

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_chart_wage_components` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`, `wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_charts_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | Check if any mappings already exist for | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cba_wage_charts_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cba_wage_charts

```sql
CREATE TEMP TABLE cba_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_charts'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Purpose**: Check if any mappings already exist for
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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` |  |
| 2 | `cba_wage_chart_id` | uuid | `cba_wage_chart_id` | uuid | Map via `cba_wage_charts_id_mapping`; zero-UUID fallback | FK lookup |
| 3 | `basic_wage_component_id` | uuid | `basic_wage_component_id` | uuid | Map via `wage_components_id_mapping`; zero-UUID fallback | FK lookup |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 8 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 12 | `created_by, updated_by, deleted_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cba_wage_charts`
- `crewing.cba_wage_charts`
- `crewing.wage_components`
- `wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Charts ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cba_wage_charts'`

```sql
CREATE TEMP TABLE cba_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_charts'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Purpose**: Check if any mappings already exist for
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

Full migration context: `04-migration-scripts/master/cba_wage_chart_wage_components_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_chart_wage_components_validation.sql` if available
- Run `06-rollback/master/cba_wage_chart_wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
