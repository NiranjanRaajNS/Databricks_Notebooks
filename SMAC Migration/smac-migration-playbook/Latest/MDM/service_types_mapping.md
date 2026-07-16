# Table Mapping: service_types → service_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: service_types
- **Source Script**: `04-migration-scripts/master/service_types_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `service_types`)

## Migration Notes

- **Seed data script** — no SAC legacy source; five reference rows inserted via hardcoded `VALUES`
- Hardcoded UUIDs per service type (Technical, MLC Ship Owner, Crewing, Accounting, Procurement)
- `tenant_id` hardcoded in seed script (not `:'DEFAULT_TENANT_ID'`); `status = 0`, `workflow_status = 2`, `defined_by = 0`
- `ON CONFLICT (id) DO UPDATE` upserts all columns on re-run
- Prerequisite master data for `companies` and vessel company associations

## Special Considerations

- Script performs `TRUNCATE TABLE public.service_types` before insert (full table reload)
- No dblink, no `migration.resolve_target_id()`, no `migration.table_mappings`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | Hardcoded UUID per seed row | SMAC-only seed; e.g. Technical = `01963dd1-5f8d-7a3a-b099-11938b981183` |
| 2 | — | — | `code` | text | Hardcoded short code per row | TN, MLC, CR, ACT, PR |
| 3 | — | — | `name` | text | Hardcoded display name | Technical, MLC Ship Owner, Crewing, Accounting, Procurement |
| 4 | — | — | `description` | text | Hardcoded description per row | Business description text per service type |
| 5 | — | — | `tenant_id` | uuid | Hardcoded tenant UUID in seed script | Not sourced from `constants.sql` in this script |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial version |
| 7 | — | — | `created_at` | timestamp without time zone | `now()` or explicit timestamp per row | MLC row uses fixed `2025-04-16` timestamps |
| 8 | — | — | `updated_at` | timestamp without time zone | `now()` or explicit timestamp per row | Same as `created_at` for MLC row |
| 9 | — | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | All seed rows active |
| 10 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not populated |
| 11 | — | — | `audit_info` | jsonb | Hardcoded JSONB with `created_by`/`updated_by` UUIDs | Per-row audit metadata in seed script |
| 12 | — | — | `max_company_count` | integer | Hardcoded per row (1 or 4) | Crewing allows 4 companies |
| 13 | — | — | `req_in_vessel_creation` | boolean | Hardcoded per row | `true` for TN, MLC, ACT; `false` for CR, PR |
| 14 | — | — | `level` | numeric | Hardcoded 1–5 | Display/hierarchy order |
| 15 | — | — | `tags` | text[] | Hardcoded tag arrays per row | e.g. `ARRAY['technical', 'TN']` |
| 16 | — | — | `status` | integer | Hardcoded `0` (Active) | All seed rows active |
| 17 | — | — | `workflow_status` | integer | Hardcoded `2` (Approved) | Not from `constants.sql` |
| 18 | — | — | `defined_by` | integer | Hardcoded `0` (Global) | Not from `constants.sql` |

**No SAC source:** All columns are SMAC seed data — no legacy column mapping applies.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/service_types_migration.sql`

## Validation

- Run `05-validation/master/service_types_validation.sql` if available
- Run `06-rollback/master/service_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
