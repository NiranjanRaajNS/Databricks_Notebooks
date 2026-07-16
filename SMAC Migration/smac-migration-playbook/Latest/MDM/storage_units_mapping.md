# Table Mapping: uom → storage_units

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: uom
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: storage_units
- **Source Script**: `04-migration-scripts/master/storage_units_migration.sql`

- **Legacy Path**: `synergy_master.enum.uom`
- **New Path**: `smac_master_migration.vessel.storage_units`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Uom (`uom` → `storage_units`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Source: `synergy_master.enum.uom` (not `public` schema)
- `code`, `name`, `description` direct copy with `TRIM()`; no `deleted_at` in source — all Active (`status = 0`)
- `created_at`/`updated_at` set to `NOW()` (not from SAC)
- Filter: `identifier IS NOT NULL`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Migrates enum.uom preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.storage_units` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id` |
| 2 | `code` | text | `code` | text | `TRIM(code)` | Direct copy from SAC `enum.uom.code` |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 9 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in SAC source |
| 10 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not from SAC source |
| 11 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not from SAC source |
| 12 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/storage_units_migration.sql`

## Validation

- Run `05-validation/master/storage_units_validation.sql` if available
- Run `06-rollback/master/storage_units_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
