# Table Mapping: airports → airports

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: airports
- **Source Script**: `04-migration-scripts/master/airports_migration.sql`


## Business Key

- **Business Key**: `s.airport_name`

## Migration Notes

- Extract distinct values from nearest_airport column in contact_details table
- Generate new UUIDs for each distinct airport value
- Record legacy value → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.airports` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_uuid_mapping` | FK lookup | `legacy_country_id`, `country_uuid` | - | `synergy_master` |

### `countries_uuid_mapping`

- **Output columns**: legacy_country_id, country_uuid
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE countries_uuid_mapping AS
SELECT DISTINCT
    c.id AS legacy_country_id,
    c.uuid AS country_uuid
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(id bigint, uuid uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | new_uuid | - | id | - | s.new_uuid AS id | s.new_uuid |
| 2 | airport_name | - | code | - | UPPER(RPAD(LEFT(REGEXP_REPLACE(TRIM(COALESCE(s.airport_name, '')), '[^A-Za-z]', '', 'g'), 3), 3, 'X')) AS code | UPPER(RPAD(LEFT(REGEXP_REPLACE(TRIM(COALESCE(s.airport_name, '')), '[^A-Za-z]', '', 'g'), 3), 3, 'X')) |
| 3 | airport_name | - | name | - | LEFT(COALESCE(s.airport_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.airport_name, 'UNKNOWN'), 255) |
| 4 | derived | - | country_id | - | COALESCE( c_mapping.country_uuid, (SELECT country_id FROM default_country), (SELECT uuid FROM dblink('synergy_master', 'SELECT uuid FROM public.countries WHERE uuid IS NOT NULL ... | COALESCE( c_mapping.country_uuid, (SELECT country_id FROM default_country), (SELECT uuid FROM dblink('synergy_master', 'SELECT uuid FROM public.countries WHERE uuid IS NOT NULL ... |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries Uuid ID Mapping
**Output columns**: `legacy_country_id, country_uuid`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE countries_uuid_mapping AS
SELECT DISTINCT
    c.id AS legacy_country_id,
    c.uuid AS country_uuid
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(id bigint, uuid uuid);
```

Full migration context: `04-migration-scripts/master/airports_migration.sql`

## Validation

- Run `05-validation/master/airports_validation.sql` if available
- Run `06-rollback/master/airports_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
