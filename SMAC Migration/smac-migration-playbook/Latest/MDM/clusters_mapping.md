# Table Mapping: cluster → clusters

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: cluster
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: clusters
- **Source Script**: `04-migration-scripts/master/clusters_migration.sql`

- **Legacy Path**: `synergy_vessel.public.cluster`
- **New Path**: `smac_master_migration.vessel.clusters`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cluster (`cluster` → `clusters`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `code` via `generate_meaningful_code(name, NULL)`
- `fleet_id` direct UUID copy
- `status` Case 2: `deleted_at` + status string
- Filter: name non-empty

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.clusters` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 4 | `fleet_id` | uuid | `fleet_id` | uuid | Direct copy | FK to fleet |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 9 | `deleted_at, status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/clusters_migration.sql`

## Validation

- Run `05-validation/master/clusters_validation.sql` if available
- Run `06-rollback/master/clusters_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
