# Table Mapping: place_of_engagements → place_of_engagements

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: place_of_engagements
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: place_of_engagements
- **Source Script**: `04-migration-scripts/master/place_of_engagements_migration.sql`

- **Legacy Path**: `synergy_master.public.place_of_engagements`
- **New Path**: `smac_master_migration.crewing.place_of_engagements`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Place of Engagements (`place_of_engagements` → `place_of_engagements`)

## Migration Notes

- Source: `synergy_master.public.place_of_engagements` → `crewing.place_of_engagements`
- SAC `id` (uuid) preserved via `resolve_target_id()` with duplicate-handling suffix on source_id
- Pre-migration duplicate UUID check on `id`
- `state_country_mapping` temp table with hardcoded CSV city→country pairs
- `country_id`: primary match `name` → `states.name`; fallback CSV → `countries.name`
- Post-migration UPDATE for remaining NULL `country_id` from CSV mapping
- Filter: non-empty `name`
- `status` Case 1 from `deleted_at`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.place_of_engagements` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `resolve_target_id()` — source_id with `_N` suffix for duplicate ids; `p_target_id = id` for first occurrence only | Handles duplicate UUIDs |
| 2 | `name` | text | `name` | text | `TRIM(name)` |  |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` |  |
| 4 | `name` | text | `country_id` | uuid | Join `states` on name; fallback `state_country_mapping` → `countries` | FK lookup |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 9 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 10 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 11 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 12 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |

**SAC columns not migrated:** None from dblink SELECT.

**Post-migration update:** NULL `country_id` rows updated via CSV state-country mapping.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/place_of_engagements_migration.sql`

## Validation

- Run `05-validation/master/place_of_engagements_validation.sql` if available
- Run `06-rollback/master/place_of_engagements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
