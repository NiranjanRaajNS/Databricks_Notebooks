# Table Mapping: cba_wage_amount_experience_tiers → cba_wage_amount_experience_tiers

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_amount_experience_tiers
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_amount_experience_tiers
- **Source Script**: `04-migration-scripts/master/cba_wage_amount_experience_tiers_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_amount_experience_tiers`
- **New Path**: `smac_master_migration.crewing.cba_wage_amount_experience_tiers`

## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `experience_tier_id`)
- **Source (orchestration)**: CBA Wage Amount Experience Tiers (`cba_wage_amount_experience_tiers` → `cba_wage_amount_experience_tiers`)

## Migration Notes

- SAC `id` (uuid) preserved
- `experience_tier_id` via INNER JOIN to `cba_wage_experience_tiers` on scale + range
- Component FKs via `table_mappings` lookups

## Special Considerations

- Source table has id column (UUID) - uses migration.resolve_target_id() to preserve legacy UUID with idempotency support
- Script performs `TRUNCATE TABLE crewing.cba_wage_amount_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `cba_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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

### `derived_wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=derived_wage_components

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

### `cba_wage_scales_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cba_wage_scales

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` |  |
| 2 | `cba_wage_scales_id, range_start, range_end` | uuid, numeric, numeric | `experience_tier_id` | uuid | INNER JOIN `cba_wage_experience_tiers` on scale + range match | FK via composite join |
| 3 | `pay` | numeric | `pay` | numeric | Direct copy |  |
| 4 | `applicable` | boolean | `applicable` | boolean | Direct copy |  |
| 5 | `basic_wage_component_id` | uuid | `basic_wage_component_id` | uuid | Map via `wage_components_id_mapping` | FK lookup |
| 6 | `derived_wage_component_id` | uuid | `derived_wage_component_id` | uuid | Map via `derived_wage_components_id_mapping` | FK lookup |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 12 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 16 | `created_by, updated_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 17 | `—` | — | `level` | numeric | Hardcoded `0` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cba_wage_charts`
- `crewing.cba_wage_experience_tiers`
- `crewing.cba_wage_scales`
- `crewing.derived_wage_components`
- `crewing.wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wage Components ID Mapping
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

### 2. Derived Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='derived_wage_components'`

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

### 3. Cba Wage Scales ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cba_wage_scales'`

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_wage_amount_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_amount_experience_tiers_validation.sql` if available
- Run `06-rollback/master/cba_wage_amount_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
