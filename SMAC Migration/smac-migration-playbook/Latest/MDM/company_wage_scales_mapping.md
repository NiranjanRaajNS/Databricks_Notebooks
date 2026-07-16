# Table Mapping: company_wage_scales → company_wage_scales

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_scales
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_scales
- **Source Script**: `04-migration-scripts/master/company_wage_scales_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_scales`
- **New Path**: `smac_master_migration.crewing.company_wage_scales`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Scales (`wage_scales` → `company_wage_scales`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `company_wage_chart_id` mapped from SAC `wage_chart_id` via `company_wage_charts_id_mapping`; `rank_id` from SAC `rank_id` via `ranks_id_mapping`
- Filter: only rows where `wage_chart_id` belongs to `wage_charts` with `type = 0` (company wage charts)
- Deduplication: `DISTINCT ON (id)` keeping latest row per `id` (`ORDER BY updated_at DESC, created_at DESC`)
- `status` derived from SAC `isdeleted`: `true` → Deleted (3), else Active (0); SAC has no `deleted_at`
- `no_of_other_allowance` hardcoded to `0`; `level` hardcoded to `0`
- `audit_info` uses `SYSTEM_USER_ID` from `constants.sql`
- Requires `company_wage_charts` and `ranks` migrated first

## Special Considerations

- Source table does not have identifier/uuid columns — idempotent UUID via `resolve_target_id()`
- Script performs `TRUNCATE TABLE crewing.company_wage_scales` before insert (full table reload)
- Orchestration dependencies: `company_wage_charts`, `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_charts_id_mapping` | Check if any mappings already exist for the given sourc | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `company_wage_charts_id_mapping`

- **Purpose**: Check if any mappings already exist for the given sourc
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_charts

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_charts'
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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `wage_chart_id` | bigint | `company_wage_chart_id` | uuid | Map via `company_wage_charts_id_mapping`; fallback empty GUID | Lookup: `migration.table_mappings` where `target_table = 'company_wage_charts'` |
| 3 | `rank_id` | bigint | `rank_id` | uuid | Map via `ranks_id_mapping`; fallback empty GUID | Lookup: `migration.table_mappings` where `target_table = 'ranks'` |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | `isdeleted` | boolean | `status` | integer | `isdeleted = true` → Deleted (3); else Active (0) | SAC uses `isdeleted` flag (no `deleted_at` column) |
| 9 | — | — | `no_of_other_allowance` | integer | Hardcoded `0` | Not available in SAC source |
| 10 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 11 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` from `constants.sql` | Standardized SMAC audit structure; `legacy_id` handled by `id_mappings` |
| 13 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |

**SMAC columns not migrated:** `deleted_at`, `tags`, `parent_id`, `archived_at` — no source equivalent in SAC `wage_scales`.

**SAC columns not migrated:** `created_by_id`, `updated_by_id` — audit uses `SYSTEM_USER_ID` instead of source values.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_charts`
- `ranks`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Charts ID Mapping
**Purpose**: Check if any mappings already exist for the given sourc
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_charts'`

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_charts'
  AND target_db = current_database();
```

### 2. Ranks ID Mapping
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

Full migration context: `04-migration-scripts/master/company_wage_scales_migration.sql`

## Validation

- Run `05-validation/master/company_wage_scales_validation.sql` if available
- Run `06-rollback/master/company_wage_scales_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
