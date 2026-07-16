# Table Mapping: ranks → ranks

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ranks
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: ranks
- **Source Script**: `04-migration-scripts/master/ranks_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks`
- **New Path**: `smac_master_migration.public.ranks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Two-phase migration: Phase 1 INSERT with `superior_rank_id = NULL`; Phase 2 UPDATE resolves `superior_rank_id` via self-reference through `migration.table_mappings`
- `officer_type`, `rank_category`, `rank_type` (bigint) → UUID via `enum.officertype`, `enum.rankcategory`, `enum.rank_type` (`identifier` column)
- `department` (text) → `rank_department_id` via `public.rank_departments` name match
- `msm_position` (text) → `msmposition_id` via `msm_position_id_mapping` (`migration.table_mappings` where `target_table = 'msm_positions'`)
- `position` → `level`; `short_code` → `code`; `is_lowest_rank` → `is_entry_level`
- `crew_type` derived: `short_code = 'SR'` → 1, else 0
- `status` derived from `deleted_at` + `is_active` (Case 3 — `deleted_at` takes precedence)
- Filter: only rows where `TRIM(name) <> ''` are migrated
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.ranks` before insert (full table reload)
- SAC has no audit columns — `audit_info` uses `SYSTEM_USER_ID` from `constants.sql`
- `staging_ranks` temp table deduplicates by `identifier` before Phase 2 update

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `superior_rank_lookup` | FK lookup | `legacy_rank_id`, `legacy_rank_identifier` | - | `synergy_master` |
| `msm_position_id_mapping` | FK lookup | `msm_position_text`, `msm_position_id` | `migration.table_mappings` (see SQL) | - |

### `superior_rank_lookup`

- **Output columns**: legacy_rank_id, legacy_rank_identifier
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE superior_rank_lookup AS
SELECT DISTINCT
    d.id AS legacy_rank_id,
    d.identifier AS legacy_rank_identifier
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS d(id bigint, identifier uuid);
```

### `msm_position_id_mapping`

- **Output columns**: msm_position_text, msm_position_id
- **migration.table_mappings**: target_table=msm_positions

```sql
CREATE TEMP TABLE msm_position_id_mapping AS
SELECT DISTINCT
    tm.source_id AS msm_position_text,
    tm.target_id AS msm_position_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'msm_positions'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `short_code` | text | `code` | text | `COALESCE(TRIM(short_code), '')` | Direct copy; empty string when NULL; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `COALESCE(name, 'UNKNOWN')` | Defaults to `'UNKNOWN'` when NULL; NOT NULL in SMAC |
| 4 | `officer_type` | bigint | `officer_type_id` | uuid | Join `enum.officertype` on `officertype.id = officer_type`; use `identifier` | Lookup: `synergy_master.enum.officertype` via dblink |
| 5 | `rank_category` | bigint | `rank_category_id` | uuid | Join `enum.rankcategory` on `rankcategory.id = rank_category`; use `identifier` | Lookup: `synergy_master.enum.rankcategory` via dblink |
| 6 | `rank_type` | bigint | `rank_type_id` | uuid | Join `enum.rank_type` on `rank_type.id = rank_type`; use `identifier` | Lookup: `synergy_master.enum.rank_type` via dblink |
| 7 | `department` | text | `rank_department_id` | uuid | Join `public.rank_departments` on `LOWER(TRIM(name)) = LOWER(TRIM(department))` | Lookup: SMAC `rank_departments` by name match; nullable if no match |
| 8 | `msm_position` | text | `msmposition_id` | uuid | Join `msm_position_id_mapping` on `TRIM(UPPER(msm_position))` | Lookup: `migration.table_mappings` where `target_table = 'msm_positions'` |
| 9 | `position` | numeric | `level` | numeric | Direct copy | SAC hierarchy order maps to SMAC `level` |
| 10 | `superior_rank_id` | bigint | `superior_rank_id` | uuid | Phase 2 UPDATE: `superior_rank_id` → `superior_rank_lookup` → `migration.table_mappings` (`ranks`) → self-reference | NULL on Phase 1 INSERT; populated in Phase 2 from ranks self-reference |
| 11 | `short_code` | text | `crew_type` | integer | `UPPER(TRIM(short_code)) = 'SR'` → 1; else 0 | Derived flag; NOT NULL in SMAC |
| 12 | `is_lowest_rank` | boolean | `is_entry_level` | boolean | `COALESCE(is_lowest_rank, false)` | SAC `is_lowest_rank` renamed to `is_entry_level` |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 14 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 15 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 17 | `deleted_at`, `is_active` | timestamp without time zone, boolean | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); `is_active = false` → Inactive (2); else Active (0) | Per project rule Case 3 — `deleted_at` takes precedence |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 21 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` for created/updated by | SAC has no audit columns; no `legacy_id` (identifier preserved as `id`) |
| 22 | `short_code`, `name` | text | `tags` | text[] | Distinct array: `short_code` tag (as-is) + normalized lowercase `name` tag | Derived search tags; not in SAC source |

**SAC columns not migrated:** `created_by_id`, `created_by_name`, `updated_by_id`, `updated_by_name` — SAC table has no audit columns used in migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Superior Rank ID Mapping
**Output columns**: `legacy_rank_id, legacy_rank_identifier`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE superior_rank_lookup AS
SELECT DISTINCT
    d.id AS legacy_rank_id,
    d.identifier AS legacy_rank_identifier
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS d(id bigint, identifier uuid);
```

### 2. Msm Position ID Mapping
**Output columns**: `msm_position_text, msm_position_id`
**migration.table_mappings**: `target_table='msm_positions'`

```sql
CREATE TEMP TABLE msm_position_id_mapping AS
SELECT DISTINCT
    tm.source_id AS msm_position_text,
    tm.target_id AS msm_position_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'msm_positions'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/ranks_migration.sql`

## Validation

- Run `05-validation/master/ranks_validation.sql` if available
- Run `06-rollback/master/ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
