# Table Mapping: competency_task_rejection_reasons → competency_task_rejection_reasons

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_task_rejection_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_task_rejection_reasons
- **Source Script**: `04-migration-scripts/master/competency_task_rejection_reasons_migration.sql`

- **Legacy Path**: `efr.public.competency_task_rejection_reasons`
- **New Path**: `smac_master_migration.crewing.competency_task_rejection_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Competency Task Rejection Reasons (`competency_task_rejection_reasons` → `competency_task_rejection_reasons`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `status` derived from `deleted_at`, then `isdeleted` when `deleted_at` is NULL
- Filter: only rows where `name IS NOT NULL AND TRIM(name) <> ''` are migrated

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.competency_task_rejection_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 5 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | `deleted_at`, `isdeleted` | timestamp, boolean | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) | `deleted_at` takes precedence; then `isdeleted` when `deleted_at` is NULL |
| 11 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 12 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `created_by_id`, `deleted_by_id`, `updated_by_id` | character varying(256) | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs | Standardized SMAC audit structure; `legacy_id` handled by `id_mappings` |

**SMAC columns not migrated:** `tags`, `parent_id`, `archived_at` — no source equivalent in SAC `competency_task_rejection_reasons`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/competency_task_rejection_reasons_migration.sql`

## Validation

- Run `05-validation/master/competency_task_rejection_reasons_validation.sql` if available
- Run `06-rollback/master/competency_task_rejection_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
