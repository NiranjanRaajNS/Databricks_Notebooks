# Table Mapping: availability_remarks → availability_remarks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: availability_remarks
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: availability_remarks
- **Source Script**: `04-migration-scripts/master/availability_remarks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.availability_remarks`
- **New Path**: `smac_master_migration.crewing.availability_remarks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Availability Remarks (`availability_remarks` → `availability_remarks`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql` (Active = 0, Approved = 2, Global = 0)
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0)
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- Filter: only rows where `name IS NOT NULL AND TRIM(name) <> ''` are migrated
- Script contains 2 INSERT blocks: primary SAC migration + seed record `'captured during sign off'` (not from SAC)

## Special Considerations

- SAC has no `uuid`/`identifier` column — UUID duplicate check is skipped gracefully if column absent
- Script performs `TRUNCATE TABLE crewing.availability_remarks` before insert (full table reload)
- Second INSERT adds SMAC-only seed row `'captured during sign off'` with `gen_random_uuid()` if code does not already exist

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `COALESCE(TRIM(description), '')` | Direct copy; empty string when NULL |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 9 | `deleted_at` | timestamp(6) without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 10 | `created_at` | timestamp(6) without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 11 | `updated_at` | timestamp(6) without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 12 | `deleted_at` | timestamp(6) without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 13 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; `legacy_id` not included (handled by `id_mappings`) |
| 14 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 15 | `name` | text | `tags` | text[] | Array of lowercase tags from generated `code` and normalized `name` (spaces/special chars → underscores) | Derived field; single tag when code and name tags are identical |

**SMAC columns not migrated:** `parent_id`, `archived_at` — no source equivalent in SAC `availability_remarks`.

**SAC columns not migrated:** `deleted_by_id`, `deleted_by_name` — deletion tracked via `deleted_at` only.

**Additional seed record (not from SAC):** `'captured during sign off'` inserted via second INSERT block with `gen_random_uuid()`, same column defaults as above.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/availability_remarks_migration.sql`

## Validation

- Run `05-validation/master/availability_remarks_validation.sql` if available
- Run `06-rollback/master/availability_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
