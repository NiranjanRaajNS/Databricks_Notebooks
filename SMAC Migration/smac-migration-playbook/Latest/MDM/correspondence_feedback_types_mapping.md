# Table Mapping: feedback_correspondence_types → correspondence_feedback_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: feedback_correspondence_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: correspondence_feedback_types
- **Source Script**: `04-migration-scripts/master/correspondence_feedback_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.feedback_correspondence_types`
- **New Path**: `smac_master_migration.crewing.correspondence_feedback_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Feedbackreasontype (`feedbackreasontype` → `correspondence_feedback_types`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `status` hardcoded to Active (0); SAC has no `deleted_at` column
- `updated_at` set to `NOW()` (SAC has `created_at` only)
- Filter: only rows where `TRIM(COALESCE(name,'')) <> ''` are migrated

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.correspondence_feedback_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC has no status/deleted_at columns |
| 9 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 10 | — | — | `updated_at` | timestamp without time zone | `NOW()` | SAC has no `updated_at` column |
| 11 | `id` | bigint | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; merged with `legacy_id = id::text` | Standardized SMAC audit structure; `legacy_id` also in `audit_info` for mapping reference |

**SMAC columns not migrated:** `deleted_at`, `level`, `tags`, `description` — no source equivalent in SAC `feedback_correspondence_types`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/correspondence_feedback_types_migration.sql`

## Validation

- Run `05-validation/master/correspondence_feedback_types_validation.sql` if available
- Run `06-rollback/master/correspondence_feedback_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
