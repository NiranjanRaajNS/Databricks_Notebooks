# Table Mapping: percentage_based_components → percentage_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: percentage_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: percentage_based_components
- **Source Script**: `04-migration-scripts/master/percentage_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.percentage_based_components`
- **New Path**: `smac_master_migration.crewing.percentage_based_components`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Percentage Based Components (`percentage_based_components` → `percentage_based_components`)

## Migration Notes

- Source: `synergy_master.wages.percentage_based_components` → `crewing.percentage_based_components`
- SAC `id` (uuid) preserved via `resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on `id`
- TRUNCATE target
- FK UUIDs copied directly (no lookup tables in script)
- `derived_from_component_type` text → integer: BASIC=1, DERIVED=2, default 1
- `status` from `isactive` (true→0, false→3 per script comment says Inactive 2 but code uses 3)

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.percentage_based_components` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Pattern 4 |
| 2 | `proportion` | numeric | `proportion` | numeric | `COALESCE(proportion, 0)` |  |
| 3 | `derived_component_id` | uuid | `derived_component_id` | uuid | Direct copy | FK uuid preserved |
| 4 | `derived_from_component_id` | uuid | `derived_from_component_id` | uuid | Direct copy | FK uuid preserved |
| 5 | `isactive` | boolean | `isactive` | boolean | `COALESCE(isactive, true)` |  |
| 6 | `derived_from_component_type` | varchar(150) | `derived_from_component_type` | integer | BASIC→1, DERIVED→2, else 1 | Text to enum int |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 11 | `isactive` | boolean | `status` | integer | `isactive = true` → Active (0); `false` → Deleted (3) |  |
| 12 | `—` | — | `created_at` | timestamp | `NOW()` | Not in SAC |
| 13 | `—` | — | `updated_at` | timestamp | `NOW()` | Not in SAC |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Pattern 4; no legacy_id |
| 15 | `—` | — | `level` | integer | Hardcoded `0` |  |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/percentage_based_components_migration.sql`

## Validation

- Run `05-validation/master/percentage_based_components_validation.sql` if available
- Run `06-rollback/master/percentage_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
