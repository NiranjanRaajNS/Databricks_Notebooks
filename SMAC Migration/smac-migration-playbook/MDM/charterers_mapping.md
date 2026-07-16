# Table Mapping: vessel_charterer_details → charterers

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_charterer_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: charterers
- **Source Script**: `04-migration-scripts/master/charterers_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_charterer_details`
- **New Path**: `smac_master_migration.vessel.charterers`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Charterer (`charterer` → `charterers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Check for duplicate UUIDs in source table

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.charterers` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `charterer_type_id_mapping` | -- Check for duplicate UUIDs in source table | `charterer_type_name`, `charterer_type_id` | - | - |
| `countries_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id`, `country_name` | `migration.table_mappings` (see SQL) | - |
| `countries_fallback_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `charterer_type_id_mapping`

- **Purpose**: -- Check for duplicate UUIDs in source table
- **Output columns**: charterer_type_name, charterer_type_id

```sql
CREATE TEMP TABLE charterer_type_id_mapping AS
SELECT
    ct.name as charterer_type_name,
    ct.id as charterer_type_id
FROM vessel.charterer_types ct;
```

### `countries_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id, country_name
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### `countries_fallback_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | name | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.name) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_charterer_details'::VARCHAR(100), LEFT(TRIM(legacy_da... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), gen_random_uuid()::text) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | charterer_type_id | - | ctm.charterer_type_id | ctm.charterer_type_id |
| 6 | derived | - | country_id | - | COALESCE( country_mapping.new_id, country_fallback.new_id ) as country_id | COALESCE( country_mapping.new_id, country_fallback.new_id ) |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'DR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'DR... |
| 12 | created_at | - | created_at | - | CASE WHEN legacy_data.created_at IS NULL THEN NOW() WHEN legacy_data.created_at = 'infinity'::timestamp OR legacy_data.created_at = '-infinity'::timestamp OR legacy_data.created... | CASE WHEN legacy_data.created_at IS NULL THEN NOW() WHEN legacy_data.created_at = 'infinity'::timestamp OR legacy_data.created_at = '-infinity'::timestamp OR legacy_data.created... |
| 13 | updated_at, created_at | - | updated_at | - | CASE WHEN legacy_data.updated_at IS NULL OR legacy_data.updated_at = 'infinity'::timestamp OR legacy_data.updated_at = '-infinity'::timestamp OR legacy_data.updated_at > '9999-1... | CASE WHEN legacy_data.updated_at IS NULL OR legacy_data.updated_at = 'infinity'::timestamp OR legacy_data.updated_at = '-infinity'::timestamp OR legacy_data.updated_at > '9999-1... |
| 14 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `charterer_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Charterer Type ID Mapping
**Purpose**: -- Check for duplicate UUIDs in source table
**Output columns**: `charterer_type_name, charterer_type_id`

```sql
CREATE TEMP TABLE charterer_type_id_mapping AS
SELECT
    ct.name as charterer_type_name,
    ct.id as charterer_type_id
FROM vessel.charterer_types ct;
```

### 2. Countries ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id, country_name`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### 3. Countries Fallback ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

Full migration context: `04-migration-scripts/master/charterers_migration.sql`

## Validation

- Run `05-validation/master/charterers_validation.sql` if available
- Run `06-rollback/master/charterers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
