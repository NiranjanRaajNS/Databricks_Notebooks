# Table Mapping: conduct → employee_conduct_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: conduct
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: employee_conduct_types
- **Source Script**: `04-migration-scripts/master/employee_conduct_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.conduct`
- **New Path**: `smac_master_migration.crewing.employee_conduct_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Conduct (`conduct` → `employee_conduct_types`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated via `generate_meaningful_code(TRIM(name), NULL)` — SAC has no `code` column
- `status` hardcoded Active (0); SAC enum table has no `deleted_at` column
- `level` hardcoded `0`; `created_at`/`updated_at` set to `NOW()` — not present in SAC source
- `audit_info` built with `SYSTEM_USER_ID` for created/updated by
- Filter: only rows where `TRIM(COALESCE(name, '')) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.employee_conduct_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 8 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC enum table has no status/deleted_at columns |
| 9 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 10 | — | — | `created_at` | timestamp without time zone | `NOW()` | SAC has no `created_at` column |
| 11 | — | — | `updated_at` | timestamp without time zone | `NOW()` | SAC has no `updated_at` column |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**SMAC columns not migrated:** `deleted_at`, `parent_id`, `archived_at`, `description`, `tags` — no source equivalent in SAC `enum.conduct`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/employee_conduct_types_migration.sql`

## Validation

- Run `05-validation/master/employee_conduct_types_validation.sql` if available
- Run `06-rollback/master/employee_conduct_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
