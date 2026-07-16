# Table Mapping: change_request_section → vessel_change_requests

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: change_request_section
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_change_requests
- **Source Script**: `04-migration-scripts/master/vessel_change_requests_migration.sql`

- **Legacy Path**: `synergy_vessel.public.change_request_section`
- **New Path**: `smac_master_migration.vessel.vessel_change_requests`

## Business Key

- **Composite Key**: (`vessel_id`, `current_revision_id`, `initiated_by`)
- **Source (orchestration)**: Vessel Change Requests (`vessel_details_cr` → `vessel_change_requests`)

## Migration Notes

- Source: `synergy_vessel.public.change_request_section` → `vessel.vessel_change_requests` (section master data)
- SAC `identifier` preserved as SMAC `id` via `COALESCE(identifier, gen_random_uuid())`
- Filter: `section_name IS NOT NULL AND TRIM(section_name) <> ''`
- `code` from SAC `code` or generated from `name` (first 15 chars uppercased)
- `workflow_status` hardcoded Draft (0); `defined_by` hardcoded Global (0)
- `status` mapped from SAC `status` string (ACTIVE/DRAFT/INACTIVE/DELETED)
- Mapping stored via `migration.store_table_mappings`
- Note: `vessel_details_cr` migrates to same target table via separate script
## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Use DISTINCT ON (source_id) to prevent duplicate mappings when multiple staging rows match the same target row
- Script performs `TRUNCATE TABLE vessel.vessel_change_requests` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `COALESCE(identifier, gen_random_uuid())` | Preserves identifier when present |
| 2 | `code, name` | text | `code` | character varying | `COALESCE(NULLIF(TRIM(code),''), UPPER(LEFT(REPLACE(TRIM(name), ' ', '_'), 15)))` | Generated when code empty |
| 3 | `name` | text | `name` | character varying | `LEFT(COALESCE(name, 'UNKNOWN'), 255)` | Truncated to 255 chars |
| 4 | `description` | text | `description` | text | `LEFT(COALESCE(description, ''), 1000)` | Truncated to 1000 chars |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not using constants.sql var in INSERT |
| 8 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not using constants.sql var in INSERT |
| 9 | `status` | character varying | `status` | integer | ACTIVE→0, DRAFT→1, INACTIVE→2, DELETED→3; default Active | String status mapping |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | All records migrated |
| 13 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 14 | `id, identifier, created_by_id, updated_by_id` | bigint, uuid, text | `audit_info` | jsonb | `jsonb_build_object` SMAC structure + `legacy_id`, `legacy_identifier` | Pattern 4 when identifier preserved |

**SAC columns not migrated:** None from staging SELECT.

**Related migration:** `vessel_details_cr` also inserts into `vessel.vessel_change_requests` (documented separately).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel_revisions`
- `vessels`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_change_requests_migration.sql`

## Validation

- Run `05-validation/master/vessel_change_requests_validation.sql` if available
- Run `06-rollback/master/vessel_change_requests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
