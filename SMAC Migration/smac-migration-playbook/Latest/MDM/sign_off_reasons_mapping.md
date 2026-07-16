# Table Mapping: sign_off_reasons → sign_off_reasons

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: sign_off_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: sign_off_reasons
- **Source Script**: `04-migration-scripts/master/sign_off_reasons_migration.sql`

- **Legacy Path**: `synergy_master.public.sign_off_reasons`
- **New Path**: `smac_master_migration.crewing.sign_off_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Sign Off Reasons (`sign_off_reasons` → `sign_off_reasons`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated from `name` via `generate_meaningful_code()`
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0)
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql`
- Filter: only rows where `identifier IS NOT NULL` and `TRIM(name) <> ''` are migrated
- Pre-migration duplicate UUID check on SAC `identifier` column
- Post-migration: updates `document.document_rules` with sign-off reason UUID references

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.sign_off_reasons` before insert (full table reload)
- All records with valid identifier migrated including those with `deleted_at IS NOT NULL`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(reason_name, NULL)` | Generated from name; NOT NULL in SMAC; no `code` column in SAC |
| 3 | `name` | text | `name` | text | `COALESCE(reason_name, 'UNKNOWN')` | Direct copy from SAC `name`; defaults to `'UNKNOWN'`; NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 12 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 13 | `name` | text | `tags` | text[] | Distinct array: generated `code` tag + normalized lowercase `name` tag | Derived search tags; not in SAC source |

**SMAC columns not migrated:** `description`, `parent_id`, `level`, `archived_at` — no source equivalent in SAC `sign_off_reasons`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/sign_off_reasons_migration.sql`

## Validation

- Run `05-validation/master/sign_off_reasons_validation.sql` if available
- Run `06-rollback/master/sign_off_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
