# Table Mapping: vessel_classes → classes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_classes
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: classes
- **Source Script**: `04-migration-scripts/master/classes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_classes`
- **New Path**: `smac_master_migration.vessel.classes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Classes (`vessel_classes` → `classes`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- `code` via `generate_meaningful_code(name, identifier::text)`
- `status` Case 2: `deleted_at` + status string
- Filter: `identifier IS NOT NULL`, name non-empty

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.classes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves identifier uuid |
| 2 | `name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(LEFT(name, 255), identifier::text)` | Generated code |
| 3 | `name` | text | `name` | text | `LEFT(COALESCE(name, 'UNKNOWN'), 255)` | NOT NULL |
| 4 | `—` | — | `description` | text | `NULL` | No description in SAC |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 9 | `deleted_at, status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Direct copy (NULL preserved) |  |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 13 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 14 | `created_by_id, updated_by_id, created_by_name, updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | No `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/classes_migration.sql`

## Validation

- Run `05-validation/master/classes_validation.sql` if available
- Run `06-rollback/master/classes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
