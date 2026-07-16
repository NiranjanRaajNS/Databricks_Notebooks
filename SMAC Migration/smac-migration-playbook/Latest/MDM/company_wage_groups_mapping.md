# Table Mapping: vessel_groups → company_wage_groups

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_groups
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_groups
- **Source Script**: `04-migration-scripts/master/company_wage_groups_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_groups`
- **New Path**: `smac_master_migration.crewing.company_wage_groups`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Groups (`vessel_groups` → `company_wage_groups`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` via `generate_meaningful_code(name, NULL)`
- `status` Case 2: `deleted_at` + status string
- Filter: name non-empty

## Special Considerations

- Source table has identifier column - preserve legacy UUID when available
- Script performs `TRUNCATE TABLE crewing.company_wage_groups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves identifier uuid |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 4 | `—` | — | `description` | text | Empty string `''` | No description in SAC |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 9 | `deleted_at, status` | timestamp without time zone, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 13 | `created_by_id, updated_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/company_wage_groups_migration.sql`

## Validation

- Run `05-validation/master/company_wage_groups_validation.sql` if available
- Run `06-rollback/master/company_wage_groups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
