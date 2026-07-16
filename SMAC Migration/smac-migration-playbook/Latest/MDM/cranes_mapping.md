# Table Mapping: crane_types → cranes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: crane_types
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: cranes
- **Source Script**: `04-migration-scripts/master/cranes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.crane_types`
- **New Path**: `smac_master_migration.vessel.cranes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cranes (`crane_types` → `cranes`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- `code` generated from `name` (first 15 chars, uppercase, spaces → underscores); SAC has no `code` column
- `crane_type_id` self-references `'DECK CRANES'` record in `vessel.cranes` (NULL if not found — e.g. first migration run)
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0) — Case 1
- Filter: only rows where `identifier IS NOT NULL` are migrated
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.cranes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_'))` | Name-based code generation; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 5 | — | — | `crane_type_id` | uuid | Self-lookup: `'DECK CRANES'` record in `vessel.cranes` via session variable | Set before migration; NULL if not found |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 9 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 10 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 11 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 12 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 13 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 15 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — empty strings converted to NULL | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 18 | — | — | `tags` | text[] | `NULL` | Not populated; not in SAC source |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** None from dblink SELECT (`id` used as source_id only).

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/cranes_migration.sql`

## Validation

- Run `05-validation/master/cranes_validation.sql` if available
- Run `06-rollback/master/cranes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
