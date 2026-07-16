# Table Mapping: rank_combination_groups → combination_matrix_groups

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combination_groups
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: combination_matrix_groups
- **Source Script**: `04-migration-scripts/master/combination_matrix_groups_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combination_groups`
- **New Path**: `smac_master_migration.crewing.combination_matrix_groups`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Combination Matrix Groups (`rank_combination_groups` → `combination_matrix_groups`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `code` via `generate_meaningful_code(name, NULL)`
- `status` from `is_active` + `deleted_at`
- Filter: name non-empty

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Script performs `TRUNCATE TABLE crewing.combination_matrix_groups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 5 | `is_doc_combination` | boolean | `is_doc_combination` | boolean | Direct copy |  |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 12 | `is_active, deleted_at` | boolean, timestamp without time zone | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) |  |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 16 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 17 | `created_by, updated_by, deleted_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` — audit user IDs in `notes` JSON |  |
| 18 | `name` | text | `tags` | text[] | Normalized name tags |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/combination_matrix_groups_migration.sql`

## Validation

- Run `05-validation/master/combination_matrix_groups_validation.sql` if available
- Run `06-rollback/master/combination_matrix_groups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
