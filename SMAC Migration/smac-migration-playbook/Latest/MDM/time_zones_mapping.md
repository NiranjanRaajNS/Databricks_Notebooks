# Table Mapping: time_zones → time_zones

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: time_zones
- **Source Script**: `04-migration-scripts/master/time_zones_migration.sql`

- **Legacy Path**: `pg_timezone_names (PostgreSQL catalog)`
- **New Path**: `smac_master_migration.public.time_zones`

## Migration Notes

- **No SAC legacy source** — data loaded from PostgreSQL catalog `pg_timezone_names`
- Filter: excludes `posix%` and `right%` timezone name prefixes
- `code` and `name` both set to IANA timezone ID (`pg_timezone_names.name`)
- `utc_offset` formatted as `±HH:MM` string from catalog `utc_offset` interval
- `id` generated via `gen_random_uuid()` (not idempotent across re-runs)
- Post-migration fix script `update_time_zones_code_to_iana.sql` may update `code` for legacy data

## Special Considerations

- Script performs `TRUNCATE TABLE public.time_zones` before insert (full table reload).
- Orchestration dependencies: `time_zones`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per row; not from catalog |
| 2 | `name` | text | `name` | text | `TRIM(timezone_name)` from `pg_timezone_names` | IANA timezone ID; NOT NULL in SMAC |
| 3 | `name` | text | `code` | text | `TRIM(timezone_name)` | Same as `name` — IANA ID used as code |
| 4 | `utc_offset` | interval | `utc_offset` | character varying(6) | Format interval as `±HH:MM` string | e.g. `+05:30`, `-10:00` |
| 5 | — | — | `dst_observed` | boolean | Hardcoded `false` | DST not computed from catalog |
| 6 | `utc_offset` | interval | `dst_offset` | character varying(6) | Same formatted offset as `utc_offset` | Mirrors base offset |
| 7 | `name`, `utc_offset` | text, interval | `description` | text | `name || ' (UTC' || utc_offset || ')'` | Human-readable label |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | — | — | `parent_id` | uuid | Hardcoded NULL | No hierarchy in source |
| 10 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY timezone_name) - 1` | Zero-based sort index |
| 11 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 12 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 13 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 14 | — | — | `status` | integer | Hardcoded `0` (Active) | All catalog rows active |
| 15 | — | — | `created_at` | timestamp without time zone | `NOW()` | Migration timestamp |
| 16 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Migration timestamp |
| 17 | — | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not applicable |
| 18 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not applicable |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure |
| 20 | — | — | `tags` | text[] | Hardcoded NULL | Not populated |

**Source:** `pg_timezone_names` PostgreSQL system catalog (not SAC dblink).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `time_zones`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/time_zones_migration.sql`

## Validation

- Run `05-validation/master/time_zones_validation.sql` if available
- Run `06-rollback/master/time_zones_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
