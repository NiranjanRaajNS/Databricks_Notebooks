# Table Mapping: cba_wage_experience_tiers → cba_wage_experience_tiers

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_experience_tiers
- **Source Script**: `04-migration-scripts/master/cba_wage_experience_tiers_migration.sql`

- **New Path**: `smac_master_migration.crewing.cba_wage_experience_tiers`

## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `experience_tier_id`)
- **Source (orchestration)**: CBA Wage Experience Tiers (`cba_wage_amount_experience_tiers` → `cba_wage_experience_tiers`)

## Migration Notes

- Deduped from `cba_wage_amount_experience_tiers` on (scale, range_start, range_end)
- New UUID via `resolve_target_id()` with `p_target_id = NULL`
- `DISTINCT ON (cba_wage_scales_id, range_start, range_end)`

## Special Considerations

- id is already UUID in source SAC - preserve legacy UUID (generate new if NULL). identifier and uuid columns are NOT available.
- Script performs `TRUNCATE TABLE crewing.cba_wage_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = legacy tier `id::text`; `p_target_id = NULL` | New idempotent UUID per tier |
| 2 | `cba_wage_scales_id` | uuid | `cba_wage_scale_id` | uuid | Map via `cba_wage_scales_id_mapping`; zero-UUID fallback | FK lookup |
| 3 | `range_start` | numeric | `range_start` | numeric | Direct copy |  |
| 4 | `range_end` | numeric | `range_end` | numeric | Direct copy |  |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 10 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 13 | `created_by, updated_by, deleted_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |

**SAC columns not migrated:** `pay`, `applicable`, `basic_wage_component_id`, `derived_wage_component_id` — migrated to `cba_wage_amount_experience_tiers`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cba_wage_charts`
- `crewing.cba_wage_scales`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Scales ID Mapping
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

Full migration context: `04-migration-scripts/master/cba_wage_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_experience_tiers_validation.sql` if available
- Run `06-rollback/master/cba_wage_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
