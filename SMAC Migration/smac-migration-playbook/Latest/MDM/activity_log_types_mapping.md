# Table Mapping: seafarer_activity_log_types → activity_log_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_log_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: activity_log_types
- **Source Script**: `04-migration-scripts/master/activity_log_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_log_types`
- **New Path**: `smac_master_migration.crewing.activity_log_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Activity Log Types (`seafarer_activity_log_types` → `activity_log_types`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `status` mapped from `is_active` boolean (true → Active 0, false → Inactive 2)
- `is_system_generated` maps from SAC `is_manual`; `is_vessel_selection_mandatory` maps from `on_vessel`
- Filter: `name IS NOT NULL`
- `level` set to 0 initially; post-migration UPDATE alphabetically
- TRUNCATE uses CASCADE (handles `activity_log_sub_types` FK)
- Second INSERT adds synthetic `'Port Arrival'` seed row

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.activity_log_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `COALESCE(TRIM(description), NULL)` | Direct copy; nullable |
| 5 | `—` | — | `level` | numeric | Hardcoded `0`; post-migration UPDATE alphabetically by name | Recalculated after insert |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | `is_active` | boolean | `status` | integer | `is_active = true` → Active (0); `false` → Inactive (2); NULL → Active (0) | No `deleted_at` in source filter |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` for created/updated by | No `legacy_id` (uuid preserved as `id`) |
| 15 | `is_manual` | boolean | `is_system_generated` | boolean | `COALESCE(is_manual, false)` | SAC `is_manual` inverted semantics as system-generated flag |
| 16 | `on_vessel` | boolean | `is_vessel_selection_mandatory` | boolean | `COALESCE(on_vessel, false)` | Direct boolean mapping |
| 17 | `name` | text | `tags` | text[] | Array from normalized name + generated code; special tag `assignment_to_vessel` for `'Assignment to Vessel'` | Derived search tags |

**SAC columns not migrated:** `identifier`, `display_order` — not referenced in migration script.

**Additional seed record (not from SAC):** `'Port Arrival'` inserted via second INSERT block.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/activity_log_types_migration.sql`

## Validation

- Run `05-validation/master/activity_log_types_validation.sql` if available
- Run `06-rollback/master/activity_log_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
