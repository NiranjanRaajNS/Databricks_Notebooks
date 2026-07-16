# Table Mapping: ship_builders → ship_builders

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ship_builders
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: ship_builders
- **Source Script**: `04-migration-scripts/master/ship_builders_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ship_builders`
- **New Path**: `smac_master_migration.vessel.ship_builders`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Builders (`ship_builders` → `ship_builders`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.ship_builders` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id`, `country_name` | `migration.table_mappings` (see SQL) | - |
| `countries_fallback_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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
| 1 | identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'ship_builders'::VARCHAR(100), legacy_data.identifier::text, current_database()::text::VARCH... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | address | - | address | - | CASE WHEN legacy_data.address IS NULL THEN NULL ELSE jsonb_build_object('full_address', NULLIF(TRIM(legacy_data.address), '')) END as address | CASE WHEN legacy_data.address IS NULL THEN NULL ELSE jsonb_build_object('full_address', NULLIF(TRIM(legacy_data.address), '')) END |
| 6 | derived | - | country_id | - | COALESCE( country_mapping.new_id, country_fallback.new_id ) as country_id | COALESCE( country_mapping.new_id, country_fallback.new_id ) |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | update_at, created_at | - | updated_at | - | COALESCE(legacy_data.update_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.update_at, legacy_data.created_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | name | - | level | - | (ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name)) - 1)::numeric AS level | (ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name)) - 1)::numeric |
| 16 | name, identifier | - | tags | - | generate_meaningful_code() | CASE WHEN LOWER(TRIM(COALESCE(generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text), ''))) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_... |
| 17 | name, identifier | - | audit_info | - | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(TRIM(COALESCE(generate_m... | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(TRIM(COALESCE(generate_m... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
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

### 2. Countries Fallback ID Mapping
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

Full migration context: `04-migration-scripts/master/ship_builders_migration.sql`

## Validation

- Run `05-validation/master/ship_builders_validation.sql` if available
- Run `06-rollback/master/ship_builders_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
