# Table Mapping: positions → positions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: positions
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: positions
- **Source Script**: `04-migration-scripts/master/positions_migration.sql`

- **Legacy Path**: `synergy_master.public.positions`
- **New Path**: `smac_master_migration.public.positions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Positions (`positions` → `positions`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `rank_id` mapped from SAC bigint via `ranks_id_mapping` (`migration.table_mappings` where `target_table = 'ranks'`)
- `engagement_type` derived from mapped `rank_id` and `short_code` (FS → 1, Supernumerary rank → 2, specific codes → 2, else 0)
- `level` mapped from SAC `position` column (integer hierarchy order)
- `code` mapped from SAC `short_code` (uppercased); SAC has no dedicated `code` column
- `status` derived from `deleted_at` + `is_active` (Case 3 — `deleted_at` takes precedence)
- Filter: only rows where `name IS NOT NULL` are migrated
- Pre-migration duplicate UUID check on SAC `identifier` column
- Post-migration: seed INSERT for `'Arm Guards'` (hardcoded UUID) and UPDATE `engagement_type = 1` for `'Family Supernumerary'`
- `supernumerary_positions` INSERT block is commented out in migration script

## Special Considerations

- Script performs `TRUNCATE TABLE public.positions` before insert (full table reload)
- Requires `ranks` table migrated first for `rank_id` FK resolution
- Orchestration dependencies: `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | - |

### `ranks_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | character varying | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 3 | `short_code` | character varying | `code` | text | `COALESCE(NULLIF(UPPER(TRIM(short_code)), ''), '')` | SAC `short_code` uppercased as SMAC `code`; empty string when NULL; NOT NULL in SMAC |
| 4 | `rank_id` | bigint | `rank_id` | uuid | Map via `ranks_id_mapping`; join on `legacy_rank_id = rank_id::text` | Lookup: `migration.table_mappings` where `target_table = 'ranks'` |
| 5 | `rank_id`, `short_code` | bigint, character varying | `engagement_type` | integer | Supernumerary rank → 2; `short_code = 'FS'` → 1; codes `ARMED_GUARD`, `SERVICE_TECHNICIAN`, `SUPERINTENDENTS`, `PASSENGER` → 2; else 0 | Derived from mapped rank + short_code; NOT NULL in SMAC; post-migration UPDATE sets `1` for `'Family Supernumerary'` |
| 6 | `position` | integer | `level` | numeric | `COALESCE(position, 0)` | SAC `position` (hierarchy order) maps to SMAC `level` |
| 7 | — | — | `description` | text | `NULL` | No equivalent in SAC; not populated |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 9 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 10 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 11 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 12 | `deleted_at`, `is_active` | timestamp without time zone, boolean | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else map `is_active` boolean/string to Active/Draft/Inactive/Deleted | Per project rule Case 3 — `deleted_at` takes precedence over `is_active` |
| 13 | `created_at` | timestamp(6) without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 14 | `updated_at` | timestamp(6) without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 16 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — UUID validation for created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 17 | `short_code`, `name` | character varying | `tags` | text[] | Distinct array: uppercase `short_code` tag + lowercase normalized `name` tag (special chars → underscores) | Derived search tags; not in SAC source |

**SMAC columns not migrated:** `parent_id`, `archived_at` — no source equivalent in SAC `positions`.

**SAC columns not migrated:** `default_tenure` — not referenced in migration script.

**Post-migration changes (not from SAC column mapping):**
- Seed INSERT: `'Arm Guards'` with hardcoded UUID `a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d`
- UPDATE: `engagement_type = 1` where `name = 'Family Supernumerary'` and `deleted_at IS NULL`

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ranks`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/positions_migration.sql`

## Validation

- Run `05-validation/master/positions_validation.sql` if available
- Run `06-rollback/master/positions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
