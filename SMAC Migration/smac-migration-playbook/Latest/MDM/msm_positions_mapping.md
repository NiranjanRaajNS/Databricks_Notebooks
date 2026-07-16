# Table Mapping: msm_positions → msm_positions

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: msm_positions
- **Source Script**: `04-migration-scripts/master/msm_positions_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks.msm_position`
- **New Path**: `smac_master_migration.public.msm_positions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Positions (`positions` → `positions`)

## Migration Notes

- Source: distinct `msm_position` from `synergy_master.public.ranks` → `public.msm_positions`
- `resolve_target_id()` with source_id = `TRIM(UPPER(msm_position))`; `p_target_id = NULL`
- TRUNCATE CASCADE (handles `ranks.msmposition_id` FK)
- Filter: `msm_position IS NOT NULL AND TRIM <> ''`
- `DISTINCT ON (TRIM(UPPER(msm_position)))` deduplication
- `status` hardcoded Active (0); timestamps set to `NOW()`

## Special Considerations

- Script performs `TRUNCATE TABLE public.msm_positions` before insert (full table reload).
- Orchestration dependencies: `ranks`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `msm_position` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = `TRIM(UPPER(msm_position))`; `p_target_id = NULL` | Text-based idempotent key |
| 2 | `msm_position` | text | `name` | text | `TRIM(msm_position)` | NOT NULL |
| 3 | `msm_position` | text | `code` | text | `generate_meaningful_code(TRIM(msm_position), NULL)` |  |
| 4 | `msm_position` | text | `description` | text | `TRIM(msm_position)` | Same as name |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 10 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 11 | `—` | — | `deleted_at` | timestamp | `NULL` |  |
| 12 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 14 | `—` | — | `tags` | text[] | `NULL` |  |
| 15 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 16 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 17 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |

**SAC columns not migrated:** All other `ranks` columns.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `ranks`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/msm_positions_migration.sql`

## Validation

- Run `05-validation/master/msm_positions_validation.sql` if available
- Run `06-rollback/master/msm_positions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
