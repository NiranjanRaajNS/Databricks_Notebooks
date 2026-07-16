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

- GROUP BY `name` from `vessel_charterer_details`
- `migration.resolve_target_id()` with source_id = name text; `p_target_id = NULL`
- `charterer_type_id` via join to `charterer_types` by name
- `country_id` via `countries_id_mapping` with deleted-country fallback
- `status` Case 2: `deleted_at` + status string
- Filter: name non-empty; charterer_type must map if present

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
| 1 | `name` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = name; `p_target_id = NULL` | Idempotent UUID per charterer name |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 4 | `—` | — | `description` | text | `NULL` | No description in SAC |
| 5 | `charterer_type` | text | `charterer_type_id` | uuid | Join `charterer_types` on name match | FK lookup |
| 6 | `country_id` | bigint | `country_id` | uuid | Map via `countries_id_mapping`; deleted-country fallback | FK lookup |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 11 | `deleted_at, status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | Sanitized (infinity/future dates → NOW()) |  |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Sanitized timestamps |  |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 15 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | SAC `audit_info` JSON not migrated |

**SAC columns not migrated:** `audit_info` JSONB — replaced with SMAC `build_audit_info()`.

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
