# Table Mapping: special_experience_type → special_experience_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: special_experience_type
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: special_experience_types
- **Source Script**: `04-migration-scripts/master/special_experience_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.special_experience_type`
- **New Path**: `smac_master_migration.crewing.special_experience_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Special Experience Type (`special_experience_type` → `special_experience_types`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `code` generated from `name` via `generate_meaningful_code()` with random UUID suffix for uniqueness
- No `deleted_at` in SAC — all records migrated as Active (`status = 0`); `deleted_at` set to NULL
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `id` column
- Mappings stored automatically by `migration.resolve_target_id()`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.special_experience_types` before insert (full table reload)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), gen_random_uuid()::text)` | Generated from name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `description` | text | Hardcoded NULL | Not in SAC source |
| 5 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 10 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 11 | — | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | No soft-delete in SAC source |
| 12 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |
| 14 | — | — | `tags` | text[] | Hardcoded NULL | Not populated |
| 15 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in source |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |

**SAC columns not migrated:** `audit_info` (jsonb) — not used; SMAC audit built via `build_audit_info()`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/special_experience_types_migration.sql`

## Validation

- Run `05-validation/master/special_experience_types_validation.sql` if available
- Run `06-rollback/master/special_experience_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
