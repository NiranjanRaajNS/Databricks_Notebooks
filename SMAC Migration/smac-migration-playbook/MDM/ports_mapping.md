# Table Mapping: ports → ports

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ports
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: ports
- **Source Script**: `04-migration-scripts/master/ports_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ports`
- **New Path**: `smac_master_migration.public.ports`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ports (`ports` → `ports`)

## Migration Notes

- Preserve legacy identifier (UUID) as id
- Map country_id using countries lookup table
- Map timezones_id using CSV file (timezone-list.csv):
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.ports` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `source_id::text`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `timezone_id_mapping` | FK lookup | `country_id`, `timezone_id` | - | - |

### `country_id_mapping`

- **Output columns**: source_id::text, target_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

### `timezone_id_mapping`

- **Output columns**: country_id, timezone_id

```sql
CREATE TEMP TABLE timezone_id_mapping AS
SELECT DISTINCT ON (c.id)
    c.id AS country_id,
    tz.id AS timezone_id
FROM timezone_csv_data csv
INNER JOIN public.countries c ON UPPER(TRIM(csv.country_code)) = UPPER(TRIM(c.iso_code))
INNER JOIN public.time_zones tz ON TRIM(csv.timezone_iana) = TRIM(tz.name)
WHERE csv.country_code IS NOT NULL
  AND TRIM(csv.country_code) <> ''
  AND csv.timezone_iana IS NOT NULL
  AND TRIM(csv.timezone_iana) <> ''
ORDER BY c.id, tz.name;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id, legacy_uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'ports'::VARCHAR(100), s.legacy_id::text, current_database()::text::VARCHAR(100), 'public'::... |
| 2 | iso_code, port_name | - | code | - | generate_meaningful_code() | COALESCE( NULLIF(TRIM(s.iso_code), ''), generate_meaningful_code(TRIM(s.port_name), '') ) |
| 3 | port_name | - | name | - | COALESCE(s.port_name, 'UNKNOWN') AS name | COALESCE(s.port_name, 'UNKNOWN') |
| 4 | discription | - | description | - | TRIM(COALESCE(s.discription, '')) AS description | TRIM(COALESCE(s.discription, '')) |
| 5 | derived | - | country_id | - | cm.target_id AS country_id | cm.target_id |
| 6 | city | - | address | - | CASE WHEN s.city IS NOT NULL AND TRIM(COALESCE(s.city, '')) <> '' THEN jsonb_build_object( 'city', TRIM(s.city), 'state', NULL, 'region', NULL, 'landmark', NULL, 'latitude', NUL... | CASE WHEN s.city IS NOT NULL AND TRIM(COALESCE(s.city, '')) <> '' THEN jsonb_build_object( 'city', TRIM(s.city), 'state', NULL, 'region', NULL, 'landmark', NULL, 'latitude', NUL... |
| 7 | latitude, latitude_direction | - | latitude | - | CASE WHEN s.latitude IS NOT NULL AND UPPER(TRIM(COALESCE(s.latitude_direction, ''))) = 'S' THEN -s.latitude WHEN s.latitude IS NOT NULL THEN s.latitude ELSE NULL END AS latitude | CASE WHEN s.latitude IS NOT NULL AND UPPER(TRIM(COALESCE(s.latitude_direction, ''))) = 'S' THEN -s.latitude WHEN s.latitude IS NOT NULL THEN s.latitude ELSE NULL END |
| 8 | longitude, longitude_direction | - | longitude | - | CASE WHEN s.longitude IS NOT NULL AND UPPER(TRIM(COALESCE(s.longitude_direction, ''))) = 'W' THEN -s.longitude WHEN s.longitude IS NOT NULL THEN s.longitude ELSE NULL END AS lon... | CASE WHEN s.longitude IS NOT NULL AND UPPER(TRIM(COALESCE(s.longitude_direction, ''))) = 'W' THEN -s.longitude WHEN s.longitude IS NOT NULL THEN s.longitude ELSE NULL END |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 11 | derived | - | version | - | 1 AS version | 1 |
| 12 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(s.updated_at, NOW()) AS updated_at | COALESCE(s.updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 15 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 16 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN s.created_by_id IS NOT NULL AND TRIM(s.created_by_id) != '' THEN s.created_by_id::varchar ELSE NULL END, NULL::varchar, CASE WHEN s.updated... |
| 17 | derived | - | timezones_id | - | COALESCE(tzm.timezone_id, '00000000-0000-0000-0000-000000000000'::uuid) AS timezones_id | COALESCE(tzm.timezone_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 18 | port_name | - | level | - | ROW_NUMBER() OVER (ORDER BY TRIM(s.port_name))::numeric AS level | ROW_NUMBER() OVER (ORDER BY TRIM(s.port_name))::numeric |
| 19 | iso_code, port_name | - | tags | - | generate_meaningful_code() | ARRAY[ COALESCE( NULLIF(TRIM(s.iso_code), ''), generate_meaningful_code(TRIM(s.port_name), '') ) |
| 20 | port_name | - | status | - | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(COALESCE(s.port_name, 'UNKNOWN')), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ] AS tags | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(COALESCE(s.port_name, 'UNKNOWN')), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ] AS tags |
| 21 | deleted_at, isdeleted | - | workflow_status | - | CASE WHEN s.deleted_at IS NOT NULL OR s.isdeleted = true THEN 3 ELSE 0 END AS status | CASE WHEN s.deleted_at IS NOT NULL OR s.isdeleted = true THEN 3 ELSE 0 END AS status |
| 22 | - | - | defined_by | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer AS workflow_status |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `source_id::text, target_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

### 2. Timezone ID Mapping
**Output columns**: `country_id, timezone_id`

```sql
CREATE TEMP TABLE timezone_id_mapping AS
SELECT DISTINCT ON (c.id)
    c.id AS country_id,
    tz.id AS timezone_id
FROM timezone_csv_data csv
INNER JOIN public.countries c ON UPPER(TRIM(csv.country_code)) = UPPER(TRIM(c.iso_code))
INNER JOIN public.time_zones tz ON TRIM(csv.timezone_iana) = TRIM(tz.name)
WHERE csv.country_code IS NOT NULL
  AND TRIM(csv.country_code) <> ''
  AND csv.timezone_iana IS NOT NULL
  AND TRIM(csv.timezone_iana) <> ''
ORDER BY c.id, tz.name;
```

Full migration context: `04-migration-scripts/master/ports_migration.sql`

## Validation

- Run `05-validation/master/ports_validation.sql` if available
- Run `06-rollback/master/ports_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
