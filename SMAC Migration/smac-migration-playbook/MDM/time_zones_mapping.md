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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Post-migration update: sets public.time_zones.code to IANA timezone ID (TRIM(name)) when code differs from name. For legacy data migrated before code stored IANA IDs. Must run after time_zones migration.

## Special Considerations

- Script performs `TRUNCATE TABLE public.time_zones` before insert (full table reload).
- Orchestration dependencies: `time_zones`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | timezone_name | - | name | - | TRIM(src.timezone_name) as name | TRIM(src.timezone_name) |
| 3 | timezone_name | - | code | - | TRIM(src.timezone_name) as code | TRIM(src.timezone_name) |
| 4 | utc_offset | - | utc_offset | - | src.utc_offset::varchar(6) as utc_offset | src.utc_offset::varchar(6) |
| 5 | derived | - | dst_observed | - | false as dst_observed | false |
| 6 | utc_offset | - | dst_offset | - | src.utc_offset::varchar(6) as dst_offset | src.utc_offset::varchar(6) |
| 7 | timezone_name, utc_offset | - | description | - | TRIM(src.timezone_name) || ' (UTC' || src.utc_offset || ')' as description | TRIM(src.timezone_name) || ' (UTC' || src.utc_offset || ')' |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | timezone_name | - | level | - | (ROW_NUMBER() OVER (ORDER BY src.timezone_name) - 1)::numeric as level | (ROW_NUMBER() OVER (ORDER BY src.timezone_name) - 1)::numeric |
| 11 | derived | - | version | - | 1 as version | 1 |
| 12 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 13 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 14 | derived | - | status | - | 0 as status | 0 |
| 15 | derived | - | created_at | - | NOW()::timestamp without time zone as created_at | NOW()::timestamp without time zone |
| 16 | derived | - | updated_at | - | NOW()::timestamp without time zone as updated_at | NOW()::timestamp without time zone |
| 17 | - | - | deleted_at | - | NULL | NULL::timestamp without time zone |
| 18 | - | - | archived_at | - | NULL | NULL::timestamp without time zone |
| 19 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 20 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/time_zones_migration.sql`

## Validation

- Run `05-validation/master/time_zones_validation.sql` if available
- Run `06-rollback/master/time_zones_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
