# Table Mapping: vaccines → vaccines

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vaccines
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: vaccines
- **Source Script**: `04-migration-scripts/master/vaccines_migration.sql`

- **Legacy Path**: `synergy_master.public.vaccines`
- **New Path**: `smac_master_migration.crewing.vaccines`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vaccines (`vaccines` → `vaccines`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated from `name` via `generate_meaningful_code()`
- SAC `position` (text) mapped to SMAC `level` (numeric) when numeric; else NULL
- No `deleted_at` in SAC — all Active (`status = 0`)
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.vaccines` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy |
| 4 | `vaccine_type` | text | `vaccine_type` | text | `TRIM(vaccine_type)` | Direct copy |
| 5 | `position` | text | `level` | numeric | Cast to numeric when matches `^-?[0-9]+\.?[0-9]*$`; else NULL | SAC `position` text → SMAC `level` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in SAC source |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vaccines_migration.sql`

## Validation

- Run `05-validation/master/vaccines_validation.sql` if available
- Run `06-rollback/master/vaccines_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
