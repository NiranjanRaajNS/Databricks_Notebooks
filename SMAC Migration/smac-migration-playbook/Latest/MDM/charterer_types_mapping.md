# Table Mapping: vessel_charterer_details (distinct charterer_type) → charterer_types

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_charterer_details (distinct charterer_type)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: charterer_types
- **Source Script**: `04-migration-scripts/master/charterer_types_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_charterer_details (distinct charterer_type)`
- **New Path**: `smac_master_migration.vessel.charterer_types`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Vessel Charterer Details (`vessel_charterer_details` → `charterer_types`)

## Migration Notes

- Distinct `charterer_type` values from `vessel_charterer_details`
- `migration.resolve_target_id()` with source_id = charterer_type text; `p_target_id = NULL`
- Filter: `charterer_type` non-empty

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.charterer_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `charterer_type` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = charterer_type text; `p_target_id = NULL` | Idempotent UUID per type value |
| 2 | `charterer_type` | text | `code` | text | `generate_meaningful_code(charterer_type, gen_random_uuid()::text)` | Generated code |
| 3 | `charterer_type` | text | `name` | text | `TRIM(charterer_type)` | NOT NULL |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 8 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 9 | `—` | — | `created_at` | timestamp without time zone | `NOW()` |  |
| 10 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` |  |
| 11 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/charterer_types_migration.sql`

## Validation

- Run `05-validation/master/charterer_types_validation.sql` if available
- Run `06-rollback/master/charterer_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
