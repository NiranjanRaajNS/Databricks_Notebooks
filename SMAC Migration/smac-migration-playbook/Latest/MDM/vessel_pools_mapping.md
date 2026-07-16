# Table Mapping: vessel_pools → vessel_pools

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_pools
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_pools
- **Source Script**: `04-migration-scripts/master/vessel_pools_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_pools`
- **New Path**: `smac_master_migration.vessel.vessel_pools`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Vessel Pools (`vessel_pools` → `vessel_pools`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `pool_status` from SAC `status` boolean via `COALESCE(status, true)`
- `status` integer derived from `status` boolean + `deleted_at` (deleted takes precedence)
- Migrate ALL records including deleted
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_pools` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 4 | `status` | boolean | `pool_status` | boolean | `COALESCE(status, true)` | SAC boolean → pool active flag |
| 5 | `status, deleted_at` | boolean, timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else map boolean to Active/Inactive | Case 2 variant |
| 6 | `created_by_id, updated_by_id, deleted_by_id` | uuid | `audit_info` | jsonb | `migration.build_audit_info()` with user IDs | Standardized SMAC structure |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 9 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 10 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 11 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 12 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 13 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 14 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |
| 15 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |
| 16 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 17 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |

**SAC columns not migrated:** None from dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_pools_migration.sql`

## Validation

- Run `05-validation/master/vessel_pools_validation.sql` if available
- Run `06-rollback/master/vessel_pools_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
