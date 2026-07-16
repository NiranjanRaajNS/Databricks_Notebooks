# Table Mapping: special_experience_type → vessel_special_experience_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: special_experience_type
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: vessel_special_experience_types
- **Source Script**: `04-migration-scripts/master/vessel_special_experience_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.special_experience_type`
- **New Path**: `smac_master_migration.crewing.vessel_special_experience_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Special Experience Types (`special_experience_type` → `vessel_special_experience_types`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- Source: `synergy_seafarer.public.special_experience_type`
- `code` generated from `name` via `generate_meaningful_code()`
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`
- `status` hardcoded Active (0)
## Special Considerations

- Script performs `TRUNCATE TABLE crewing.vessel_special_experience_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `LEFT(TRIM(name), 255)` | Truncated to 255 chars |
| 4 | `—` | — | `description` | text | `NULL` | Not in SAC source |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No deleted_at in SAC |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `—` | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 15 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |
| 17 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |

**SAC columns not migrated:** None from dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_special_experience_types_migration.sql`

## Validation

- Run `05-validation/master/vessel_special_experience_types_validation.sql` if available
- Run `06-rollback/master/vessel_special_experience_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
