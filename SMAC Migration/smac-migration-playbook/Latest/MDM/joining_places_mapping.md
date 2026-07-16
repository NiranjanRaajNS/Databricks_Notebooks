# Table Mapping: place_of_engagements → joining_places

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: place_of_engagements
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: joining_places
- **Source Script**: `04-migration-scripts/master/joining_places_migration.sql`

- **Legacy Path**: `synergy_master.public.place_of_engagements`
- **New Path**: `smac_master_migration.public.joining_places`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Joining Places (`seafarers` → `joining_places`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Source table is `place_of_engagements` (not seafarers); target table is `joining_places`
- `code` generated from `name` via `generate_meaningful_code(TRIM(name), NULL)`
- `status` derived from `deleted_at` only (Case 1 — NULL = Active/0, NOT NULL = Deleted/3)
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `id` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.joining_places` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — only `deleted_at` in SAC |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |

**SMAC columns not migrated:** `deleted_at`, `level`, `parent_id`, `archived_at`, `description`, `tags` — no source equivalent or not populated from SAC `place_of_engagements`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/joining_places_migration.sql`

## Validation

- Run `05-validation/master/joining_places_validation.sql` if available
- Run `06-rollback/master/joining_places_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
