# Table Mapping: appraisal_types → appraisal_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: appraisal_types
- **Source Script**: `04-migration-scripts/master/appraisal_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_types`
- **New Path**: `smac_master_migration.crewing.appraisal_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Types (`appraisal_types` → `appraisal_types`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `code` generated from `name` via `generate_meaningful_code(TRIM(name), NULL)`
- `level` mapped from SAC `position` column (hierarchy order)
- `status` derived from `is_active` boolean (true → Active/0, false → Inactive/2)
- Filter: `name IS NOT NULL` and `TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `uuid` column
- No `deleted_at` column in SAC source — all active/inactive records migrated

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.appraisal_types` before insert (full table reload)
- `auto_initiate_on_event` set to `1` only for `'Sign Off'` appraisal type name

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated business code from name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` when non-empty; else NULL | NULL and empty strings normalized to NULL |
| 5 | `position` | integer | `level` | numeric | `COALESCE(position, 0)` | SAC `position` (hierarchy order) maps to SMAC `level` |
| 6 | — | — | `appraisal_mode` | integer | Hardcoded NULL | No equivalent in SAC source |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 11 | `is_active` | boolean | `status` | integer | `is_active = true` → Active (0); `is_active = false` → Inactive (2) | Boolean-to-integer mapping; no `deleted_at` in SAC |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (uuid preserved as `id`) |
| 15 | — | — | `requires_objective_setup` | boolean | Hardcoded `false` | No equivalent in SAC source; NOT NULL default |
| 16 | — | — | `requires_confirmation_stage` | boolean | Hardcoded `false` | No equivalent in SAC source; NOT NULL default |
| 17 | `name` | text | `auto_initiate_on_event` | integer | `1` when `TRIM(name) = 'Sign Off'`; else NULL | Business rule for Sign Off appraisal type only |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/appraisal_types_migration.sql`

## Validation

- Run `05-validation/master/appraisal_types_validation.sql` if available
- Run `06-rollback/master/appraisal_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
