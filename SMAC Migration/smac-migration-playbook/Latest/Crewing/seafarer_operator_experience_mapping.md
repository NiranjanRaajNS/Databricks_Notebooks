# Table Mapping: sea_experience_summary → seafarer_operator_experience

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: sea_experience_summary
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_operator_experience
- **Source Script**: `04-migration-scripts/crewing/seafarer_operator_experience_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.sea_experience_summary`
- **New Path**: `smac_crewing_migration.public.seafarer_operator_experience`

## Business Key

- **Business Key**: `seafarer_id`
- **Source (orchestration)**: Sea Experience Summary (`sea_experience_summary` → `seafarer_operator_experience`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id::uuid`
- Pre-migration duplicate UUID check on SAC `id` column
- `DISTINCT ON (id)` deduplicates source rows
- `operator_experience` (numeric) → `operator_experience_in_days` (integer); default 0
- `is_last_synergy_experience` → `is_last_experience_inhouse` (boolean); default false
- `seafarer_id` via `seafarer_id_mapping`; nil UUID if unmapped
- `status` hardcoded `'Active'`; `archived_at`, `deleted_at` = `NULL`
- Uses `migration.build_audit_info()` with created/updated by names in `notes`
- Requires `seafarers` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_operator_experience` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Delete mappings from migration.table_mappings | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Purpose**: Delete mappings from migration.table_mappings
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id::uuid` | Preserves SAC uuid as SMAC `id` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` where `target_table = 'seafarers'` |
| 3 | `operator_experience` | numeric | `operator_experience_in_days` | integer | `COALESCE(operator_experience::integer, 0)` at INSERT; **overwritten** post-migration | See Post-Migration Updates (`update_operator_exp.sql`) |
| 4 | `is_last_synergy_experience` | boolean | `is_last_experience_inhouse` | boolean | `COALESCE(is_last_synergy_experience, false)` | SAC synergy flag → inhouse flag |
| 5 | — | — | `status` | text | Hardcoded `'Active'` | All migrated records set to Active |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 9 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 10 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 11 | `created_by_id`, `updated_by_id`, names | text | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` |- |

**SMAC columns not migrated:** None beyond explicit NULLs.

**SAC columns not migrated:** None — all SAC columns in SELECT are mapped or used in audit.

### Post-Migration Updates (`update_operator_exp.sql`)

Replaces `operator_experience_in_days` from a **different SAC table** than the migration source (`sea_experience_summary`).

| Target Table | Target Column | Legacy Source Table | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|---------------------|---------------|-------------|----------------|------------|
| `public.seafarer_operator_experience` | `operator_experience_in_days` | `public.sea_experiences` | `from_date`, `to_date`, `is_synergy_experiance`, `seafarer_id` | date, date, boolean, bigint | `SUM(GREATEST(0, ROUND((COALESCE(to_date, CURRENT_DATE) - from_date)::numeric)))::integer` per `seafarer_id` | `is_synergy_experiance = true`; `from_date IS NOT NULL`; `seafarer_id` mapped via `table_mappings` |

**Lookup tables:** `migration.table_mappings` (`target_table = 'seafarers'`).

**Run order:** After `seafarer_operator_experience_migration.sql` and `seafarers` migration.

**Notes:** Initial migration reads `sea_experience_summary.operator_experience`; this update recalculates from aggregated `sea_experiences` synergy rows on SAC (remote `GROUP BY` via dblink). Updates only when value differs.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Delete mappings from migration.table_mappings
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_operator_experience_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_operator_experience_validation.sql` if available
- Run `06-rollback/crewing/seafarer_operator_experience_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
