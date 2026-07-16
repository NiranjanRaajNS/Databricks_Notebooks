# Table Mapping: countries → countries

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: countries
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: countries
- **Source Script**: `04-migration-scripts/master/countries_migration.sql`

- **Legacy Path**: `synergy_master.public.countries`
- **New Path**: `smac_master_migration.public.countries`

## Business Key

- **Business Key**: `iso_code`
- **Source (orchestration)**: Countries (`countries` → `countries`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `code` generated from `name` + `alpha2_code` via `generate_meaningful_code()` — no code column in SAC
- `alpha2_code` maps to SMAC `iso_code`
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0)
- `level` assigned sequentially via `ROW_NUMBER()` ordered by name — SAC `position` column is not used
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql`
- Pre-migration duplicate UUID check on SAC `uuid` column
- No FK lookup tables required

## Special Considerations

- Script performs `TRUNCATE TABLE public.countries` before insert (full table reload)
- All SAC records migrated including those with `deleted_at IS NOT NULL`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `alpha2_code` | text | `code` | text | `generate_meaningful_code(TRIM(name), TRIM(alpha2_code))` | Generated business code; NOT NULL in SMAC; no `code` column in SAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `alpha2_code` | text | `iso_code` | text | `COALESCE(NULLIF(TRIM(alpha2_code), ''), '')` | SAC ISO alpha-2 code renamed to `iso_code`; empty string when NULL; NOT NULL in SMAC |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 9 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 11 | — | — | `level` | numeric | `(ROW_NUMBER() OVER (ORDER BY TRIM(name))::numeric / 1.0)::numeric(10,1)` | Sequential values (1.0, 2.0, …) sorted alphabetically by name; SAC `position` not used |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (uuid preserved as `id`) |

**SMAC columns not migrated:** `description`, `parent_id`, `archived_at`, `tags` — no source equivalent in SAC `countries`.

**SAC columns not migrated:** `position` — selected in dblink but not used; SMAC `level` is derived from `ROW_NUMBER()` on name instead.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/countries_migration.sql`

## Validation

- Run `05-validation/master/countries_validation.sql` if available
- Run `06-rollback/master/countries_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
