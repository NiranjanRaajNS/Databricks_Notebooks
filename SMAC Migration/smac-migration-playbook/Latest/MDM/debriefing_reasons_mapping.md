# Table Mapping: reason_for_debrief → debriefing_reasons

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: reason_for_debrief
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: debriefing_reasons
- **Source Script**: `04-migration-scripts/master/debriefing_reasons_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.reason_for_debrief`
- **New Path**: `smac_master_migration.crewing.debriefing_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Debriefing Reasons (`reason_for_debrief` → `debriefing_reasons`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `code` generated from `name`: uppercase with spaces replaced by underscores
- `status` derived from `deleted_at` only (Case 1 — NULL = Active/0, NOT NULL = Deleted/3)
- Default values: `category = 1`, `requires_appraisal_link = false`, `level = 1`, `defined_by = 1` (Tenant)
- `tags` hardcoded to `ARRAY['DEBRIEF']`
- Pre-migration duplicate UUID check on SAC `id` column
- Master/reference table — must be migrated before `seafarer_debriefs`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.debriefing_reasons` before insert (full table reload)
- Clears existing `migration.table_mappings` for `debriefing_reasons` before migration

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | character varying | `code` | text | `UPPER(REPLACE(TRIM(name), ' ', '_'))` | Generated from name; NOT NULL in SMAC |
| 3 | `name` | character varying | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | `description` | character varying | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 5 | — | — | `category` | integer | Hardcoded `1` | Business-defined default; not in SAC source |
| 6 | — | — | `requires_appraisal_link` | boolean | Hardcoded `false` | Not in SAC source; NOT NULL default |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 8 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 9 | — | — | `level` | numeric | Hardcoded `1` | Default hierarchy level; not in SAC source |
| 10 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 11 | — | — | `defined_by` | integer | Hardcoded `1` (Tenant) | Overrides `DEFAULT_DEFINED_BY`; business-defined default |
| 12 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 13 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — only `deleted_at` in SAC |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 16 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 17 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 18 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs; names in `notes` | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |
| 19 | — | — | `tags` | text[] | Hardcoded `ARRAY['DEBRIEF']` | Default tag array; not in SAC source |

**SAC columns not migrated:** `deleted_by_name` — present in source dblink but not used in migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/debriefing_reasons_migration.sql`

## Validation

- Run `05-validation/master/debriefing_reasons_validation.sql` if available
- Run `06-rollback/master/debriefing_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
