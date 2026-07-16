# Table Mapping: cba_wage_scales → cba_wage_scales

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_scales
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_scales
- **Source Script**: `04-migration-scripts/master/cba_wage_scales_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_scales`
- **New Path**: `smac_master_migration.crewing.cba_wage_scales`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: CBA Wage Scales (`cba_wage_scales` → `cba_wage_scales`)

## Migration Notes

- SAC `id` (uuid) preserved
- FK lookups: `cba_wage_chart_id` → charts, `position_id` → positions, `rank_id` → ranks
- Zero-UUID fallbacks when mappings missing

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_scales` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_charts_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `positions_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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

### `positions_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=positions

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `cba_wage_chart_id` | uuid | `cba_wage_chart_id` | uuid | Map via `cba_wage_charts_id_mapping`; zero-UUID fallback | FK lookup |
| 3 | `position_id` | bigint | `position_id` | uuid | Map via `positions_id_mapping` | FK lookup |
| 4 | `rank_id` | bigint | `rank_id` | uuid | Map via `ranks_id_mapping` | FK lookup |
| 5 | `with_superior_certificate` | boolean | `with_superior_certificate` | boolean | Direct copy |  |
| 6 | `wage_defined_by_experience` | boolean | `wage_defined_by_experience` | boolean | Direct copy |  |
| 7 | `scope` | character varying | `scope` | text | Direct copy |  |
| 8 | `cycle` | character varying | `cycle` | text | Direct copy |  |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 16 | `created_by, updated_by, deleted_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 17 | `—` | — | `level` | numeric | Hardcoded `0` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_charts`

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

### 2. Positions ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='positions'`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

### 3. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_wage_scales_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_scales_validation.sql` if available
- Run `06-rollback/master/cba_wage_scales_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
