# Table Mapping: ppe_component_masters → working_gear

## Overview
- **Legacy Database**: synergy_manning_po
- **Legacy Schema**: public
- **Legacy Table**: ppe_component_masters
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: working_gear
- **Source Script**: `04-migration-scripts/master/working_gear_migration.sql`

- **Legacy Path**: `synergy_manning_po.public.ppe_component_masters`
- **New Path**: `smac_master_migration.crewing.working_gear`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Working Gear (`working_gear` → `working_gear`)

## Migration Notes

- SAC `"Id"` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = "Id"`
- `code` generated from `name` via `generate_meaningful_code()`
- `status` derived from `deleted_at` only (Case 1)
- `is_adhoc` merged into `audit_info` JSONB via `|| jsonb_build_object('is_adhoc', ...)`
- `measurement` (jsonb) mapped to SMAC `unit_size`
- Pre-migration duplicate UUID check on SAC `"Id"` column
- Migrate ALL records including deleted ones

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.working_gear` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `"Id"` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `"Id"::text`; `p_target_id = "Id"` | Preserves SAC UUID as SMAC `id` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `description` | text | Hardcoded NULL | Not in SAC source |
| 5 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `deleted_at` | timestamp with time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 12 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Cast to timestamp without time zone |
| 13 | `updated_at` | timestamp with time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Cast to timestamp without time zone |
| 14 | `deleted_at` | timestamp with time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `name` | text | `tags` | text[] | `ARRAY[generate_meaningful_code(name, NULL), LOWER(TRIM(name))]` | Derived search tags |
| 17 | `is_adhoc` | boolean | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID, ...)` merged with `{'is_adhoc': is_adhoc}` | Standardized audit + legacy `is_adhoc` flag |
| 18 | `sizable` | boolean | `sizable` | boolean | `COALESCE(sizable, false)` | Direct copy with default |
| 19 | `measurement` | jsonb | `unit_size` | jsonb | Direct copy | Size/measurement JSON from SAC |

**SAC columns not migrated:** `created_by`, `updated_by`, `deleted_by` (text names) — not mapped to SMAC audit fields.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/working_gear_migration.sql`

## Validation

- Run `05-validation/master/working_gear_validation.sql` if available
- Run `06-rollback/master/working_gear_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
