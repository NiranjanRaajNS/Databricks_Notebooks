# Table Mapping: training_types → training_type

## Overview
- **Legacy Database**: synergy_training
- **Legacy Schema**: public
- **Legacy Table**: training_types
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: training_type
- **Source Script**: `04-migration-scripts/master/training_types_migration.sql`

- **Legacy Path**: `synergy_training.public.training_types`
- **New Path**: `smac_crewing_migration.crewing.training_type`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Training Types (`training_types` → `training_type`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `code` generated from `name` + `id` via `generate_meaningful_code()`
- `status` derived from `deleted_at` only (Case 1)
- Timestamps cast from `timestamp with time zone` to `timestamp without time zone`
- Pre-migration duplicate UUID check on SAC `id` column
- Prerequisite master table — must be migrated before `training_master`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.training_type` before insert (full table reload)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID as SMAC `id` |
| 2 | `name`, `id` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(COALESCE(name, 'UNKNOWN')), id::text)` | Generated business code |
| 3 | `name` | text | `name` | text | `TRIM(COALESCE(name, 'UNKNOWN'))` | Defaults to `'UNKNOWN'` when NULL |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 7 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `deleted_at` | timestamp with time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 12 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Cast to timestamp without time zone |
| 13 | `updated_at` | timestamp with time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Cast to timestamp without time zone |
| 14 | `deleted_at` | timestamp with time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name`, `deleted_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs; names in `notes` | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |
| 17 | — | — | `tags` | text[] | Hardcoded NULL | Not populated |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/training_types_migration.sql`

## Validation

- Run `05-validation/master/training_types_validation.sql` if available
- Run `06-rollback/master/training_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
