# Table Mapping: bloodgroups → bloodgroups

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: bloodgroups
- **Source Script**: `04-migration-scripts/master/bloodgroups_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarers.blood_group (distinct values)`
- **New Path**: `smac_master_migration.public.bloodgroups`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Bloodgroups (`seafarers` → `bloodgroups`)

## Migration Notes

- Distinct `blood_group` values from `seafarers` table (not a dedicated SAC master table)
- Source_id = canonical blood group text (spaces removed, uppercased)
- `migration.resolve_target_id()` with `p_target_id = NULL`
- Filter: `blood_group IS NOT NULL AND TRIM(blood_group) <> ''`
- `level` via `ROW_NUMBER() OVER (ORDER BY blood_group)`

## Special Considerations

- Script performs `TRUNCATE TABLE public.bloodgroups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `blood_group` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = canonical blood_group text; `p_target_id = NULL` | Idempotent UUID from blood group value |
| 2 | `blood_group` | text | `code` | text | `UPPER(REPLACE(TRIM(blood_group), ' ', ''))` | Canonical normalized code |
| 3 | `blood_group` | text | `name` | text | Same as code (canonical blood group) | NOT NULL in SMAC |
| 4 | `—` | — | `description` | text | `NULL` | No description in source |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status in source |
| 10 | `blood_group` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY blood_group)` | Hierarchy from sort order |
| 11 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No timestamps in source |
| 12 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | No timestamps in source |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in source |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/bloodgroups_migration.sql`

## Validation

- Run `05-validation/master/bloodgroups_validation.sql` if available
- Run `06-rollback/master/bloodgroups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
