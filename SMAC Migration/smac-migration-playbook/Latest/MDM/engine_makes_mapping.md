# Table Mapping: engine_make → engine_makes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: engine_make
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: engine_makes
- **Source Script**: `04-migration-scripts/master/engine_makes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.engine_make`
- **New Path**: `smac_master_migration.vessel.engine_makes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Engine Make (`engine_make` → `engine_makes`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated via `generate_meaningful_code(COALESCE(name, 'UNKNOWN'), identifier::text)`
- `status` derived from `deleted_at` + `status` varchar (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Filter: only rows where `identifier IS NOT NULL AND TRIM(COALESCE(name, '')) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.engine_makes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(COALESCE(name, 'UNKNOWN'), identifier::text)` | Generated from name + identifier; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `COALESCE(name, 'UNKNOWN')` | Direct copy with UNKNOWN fallback; NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 12 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**SMAC columns not migrated:** `parent_id`, `archived_at`, `description`, `tags` — no source equivalent in SAC `engine_make`.

**SAC columns not migrated:** `audit_info` (jsonb) — SAC audit fields not mapped; SMAC uses `build_audit_info()` with system user defaults.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/engine_makes_migration.sql`

## Validation

- Run `05-validation/master/engine_makes_validation.sql` if available
- Run `06-rollback/master/engine_makes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
