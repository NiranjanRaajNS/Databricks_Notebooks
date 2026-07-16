# Table Mapping: basic_wage_components → wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: basic_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: wage_components
- **Source Script**: `04-migration-scripts/master/wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.basic_wage_components`
- **New Path**: `smac_master_migration.crewing.wage_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Wage Components (`basic_wage_components` → `wage_components`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- Source: `synergy_master.wages.basic_wage_components`
- `code` generated from `name` and `identifier` via `generate_meaningful_code()`
- `type`: EARNING→1, DEDUCTION→2; `payment_frequency`: MONTHLY→1, ONETIME→2
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`
- `status` derived from `deleted_at` only (Case 1)
## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.wage_components` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `name, identifier` | text, text | `code` | text | `generate_meaningful_code(name, identifier)` | Generated code |
| 4 | `—` | — | `description` | text | `NULL` | Not in SAC source |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 6 | `type` | text | `type` | integer | EARNING→1, DEDUCTION→2; default 1 | Text to integer enum |
| 7 | `payment_frequency` | text | `payment_frequency` | integer | MONTHLY→1, ONETIME→2; default 1 | Text to integer enum |
| 8 | `account_code` | text | `account_code` | text | `TRIM(account_code)` | Direct copy |
| 9 | `is_optional` | boolean | `is_optional` | boolean | `COALESCE(is_optional, false)` | Direct copy with default |
| 10 | `—` | — | `is_system_defined` | boolean | Hardcoded `false` | Not in SAC source |
| 11 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 12 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 13 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 14 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 15 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 |
| 16 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 17 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 18 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 19 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 20 | `created_by, updated_by` | text | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` with created/updated by names in notes | Name fields in p_notes |

"**SAC columns not migrated:** `identifier` (used only in code generation

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/wage_components_migration.sql`

## Validation

- Run `05-validation/master/wage_components_validation.sql` if available
- Run `06-rollback/master/wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
