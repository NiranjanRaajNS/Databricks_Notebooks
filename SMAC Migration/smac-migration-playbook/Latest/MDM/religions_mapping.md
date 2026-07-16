# Table Mapping: religions → religions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: religions
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: religions
- **Source Script**: `04-migration-scripts/master/religions_migration.sql`

- **Legacy Path**: `synergy_master.public.religions`
- **New Path**: `smac_master_migration.public.religions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Religions (`religions` → `religions`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` mapped from `name` via religion-specific 3-letter abbreviations (HINDU→HIN, CHRISTIAN→CHR, etc.); fallback: first 3 chars uppercased
- `status` derived from `deleted_at` only (Case 1 — NULL = Active/0, NOT NULL = Deleted/3)
- `level` assigned via `ROW_NUMBER()` sorted alphabetically by name
- `description` not populated (NULL)
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.religions` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | CASE mapping to 3-letter codes (HIN, CHR, ISL, BUD, SIK, ZOR, BAH, JUD, JAI, SHI, TAO, CON, ATH, AGN, NONE); else `UPPER(REPLACE(LEFT(TRIM(name), 3), ' ', '_'))` | Business code derived from religion name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `description` | text | Hardcoded NULL | No description in SAC source |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 9 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — only `deleted_at` in SAC |
| 10 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name))` | Sequential hierarchy index sorted alphabetically by name |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 14 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**SMAC columns not migrated:** `parent_id`, `archived_at`, `tags` — no source equivalent in SAC `religions`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/religions_migration.sql`

## Validation

- Run `05-validation/master/religions_validation.sql` if available
- Run `06-rollback/master/religions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
