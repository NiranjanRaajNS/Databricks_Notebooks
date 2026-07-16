# Table Mapping: cba_types → cba_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cba_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_types
- **Source Script**: `04-migration-scripts/master/cba_types_migration.sql`

- **Legacy Path**: `synergy_master.public.cba_types`
- **New Path**: `smac_master_migration.crewing.cba_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cba Types (`cba_types` → `cba_types`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `code` from `UPPER(TRIM(identifier))`
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `identifier` | text | `code` | text | `UPPER(TRIM(identifier))` | SAC identifier as code |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 10 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 13 | `identifier, name` | text, text | `tags` | text[] | Array from identifier + normalized name |  |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/cba_types_migration.sql`

## Validation

- Run `05-validation/master/cba_types_validation.sql` if available
- Run `06-rollback/master/cba_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
