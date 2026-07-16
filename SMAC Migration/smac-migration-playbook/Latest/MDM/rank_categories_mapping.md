# Table Mapping: rankcategory → rank_categories

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: rankcategory
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: rank_categories
- **Source Script**: `04-migration-scripts/master/rank_categories_migration.sql`

- **Legacy Path**: `synergy_master.enum.rankcategory`
- **New Path**: `smac_master_migration.public.rank_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- Source: `synergy_master.enum.rankcategory` → `public.rank_categories`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- TRUNCATE target
- `code` CASE mapping: RATINGS→RAT, OFFICER→OFF, etc.; fallback first 3 chars
- Filter: `identifier IS NOT NULL` and non-empty `name`
- `status`/`level` hardcoded `0`; timestamps `NOW()`
## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_categories` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` |  |
| 2 | `name` | text | `code` | text | CASE: RATINGS→`RAT`, OFFICER→`OFF`, SUPERNUMERARY→`SUP`, etc.; else first 3 chars |  |
| 3 | `name` | text | `name` | text | `COALESCE(TRIM(name), 'UNKNOWN')` |  |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 8 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 11 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** Legacy integer `id` (not selected).

**SMAC columns not migrated:** `deleted_at`, `description`, `tags`.",
)

# --- rank_combinations ---
set_update(
    "rank_combinations",
    [
        "- Source: `synergy_master.public.rank_combinations` → `crewing.rank_combinations`",
        "- SAC `id` (uuid) preserved via `resolve_target_id()` with `p_target_id = id`",
        "- `ranks_id_mapping` FK lookup for primary/secondary rank integer IDs",
        "- TRUNCATE target; migrates all rows even if FK mapping missing",
        "- `status` Case 3 from `deleted_at` + `is_active` boolean",
        "- `audit_info` uses SAC `created_by`/`updated_by`/`deleted_by` text fields",
    ],
    [
        row(1, "id", "uuid", "id", "uuid", "`migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id`", "Pattern 4
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/rank_categories_migration.sql`

## Validation

- Run `05-validation/master/rank_categories_validation.sql` if available
- Run `06-rollback/master/rank_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
