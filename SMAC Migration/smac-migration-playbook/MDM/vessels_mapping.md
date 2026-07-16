# Table Mapping: vessels → vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessels
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessels
- **Source Script**: `04-migration-scripts/master/vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessels`
- **New Path**: `smac_master_migration.vessel.vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- Uses migration.resolve_target_id() to preserve legacy uuid (UUID) as id when available
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.categories, vessel.sub_categories, vessel.ship_builders, and public.countries to be migrated first (for FK mappings)
- ship_builder_id comes from vessel_details.ship_builder (uuid) mapped to vessel.ship_builders.id (uuid)
- yard_country_id comes from vessel_details.yard_country_id (bigint) mapped to public.countries.id (uuid)

## Special Considerations

- Run schema discovery first to verify uuid column exists
- Rule 2.2.1 Case 2: deleted_at takes precedence over status
- Script performs `TRUNCATE TABLE vessel.vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `category_id_mapping` | FK lookup | `source_category_id`, `target_category_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_sub_category_id_mapping` | FK lookup | `source_sub_category_id`, `target_sub_category_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `country_id_mapping` | FK lookup | `source_country_id`, `target_country_id` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `ship_builder_id_mapping` | FK lookup | `source_ship_builder_id`, `target_ship_builder_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_details_lookup` | FK lookup | `legacy_vessel_id`, `vd.class_no`, `vessel_name`, `legacy_yard_country_id`, `legacy_ship_builder_id` | - | `synergy_vessel` |

### `category_id_mapping`

- **Output columns**: source_category_id, target_category_id
- **migration.table_mappings**: target_table=categories
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS source_category_id,
    vc.identifier::uuid AS target_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_categories'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### `vessel_sub_category_id_mapping`

- **Output columns**: source_sub_category_id, target_sub_category_id
- **migration.table_mappings**: target_table=sub_categories
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vsc.id::bigint AS source_sub_category_id,
    vsc.identifier::uuid AS target_sub_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_sub_categories'
) AS vsc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'sub_categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vsc.id
);
```

### `country_id_mapping`

- **Output columns**: source_country_id, target_country_id
- **migration.table_mappings**: target_table=countries
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_country_id,
    target_id AS target_country_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    c.id::bigint AS source_country_id,
    c.uuid::uuid AS target_country_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(
    id bigint,
    uuid uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'countries'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = c.id
);
```

### `ship_builder_id_mapping`

- **Output columns**: source_ship_builder_id, target_ship_builder_id
- **migration.table_mappings**: target_table=ship_builders
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE ship_builder_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS source_ship_builder_id,
    target_id AS target_ship_builder_id
FROM migration.table_mappings
WHERE target_table = 'ship_builders'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    sb.identifier::uuid AS source_ship_builder_id,
    sb.identifier::uuid AS target_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.ship_builders WHERE identifier IS NOT NULL'
) AS sb(
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'ship_builders'
      AND tm.target_db = current_database()
      AND tm.source_id::uuid = sb.identifier
);
```

### `vessel_details_lookup`

- **Output columns**: legacy_vessel_id, vd.class_no, vessel_name, legacy_yard_country_id, legacy_ship_builder_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.class_no,
    vd.name AS vessel_name,
    vd.yard_country_id AS legacy_yard_country_id,
    vd.ship_builder AS legacy_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT vessel_id, class_no, name, yard_country_id, ship_builder, status, updated_at
     FROM public.vessel_details
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    class_no text,
    name text,
    yard_country_id bigint,
    ship_builder uuid,
    status text,
    updated_at timestamp
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id, legacy_uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessels'::VARCHAR(100), s.legacy_id::text, current_database()::text::VARCHAR(100), 'vessel'... |
| 2 | vessel_name, name | - | name | - | COALESCE(TRIM(s.vessel_name), TRIM(s.name), 'UNKNOWN') AS name | COALESCE(TRIM(s.vessel_name), TRIM(s.name), 'UNKNOWN') |
| 3 | imo_number | - | imo_number | - | COALESCE(s.imo_number::text, '') AS imo_number | COALESCE(s.imo_number::text, '') |
| 4 | derived | - | category_id | - | cat_mapping.target_category_id AS category_id | cat_mapping.target_category_id |
| 5 | derived | - | sub_category_id | - | subcat_mapping.target_sub_category_id AS sub_category_id | subcat_mapping.target_sub_category_id |
| 6 | vessel_status, legacy_deleted_at, status | - | vessel_status | - | CASE WHEN s.vessel_status IS NULL THEN CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 8 WHEN TRIM(s.status) = '0' THEN 8 WHEN TRIM(s.status) = '1' THEN 3 ELSE 3 END WHEN UPPER(T... | CASE WHEN s.vessel_status IS NULL THEN CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 8 WHEN TRIM(s.status) = '0' THEN 8 WHEN TRIM(s.status) = '1' THEN 3 ELSE 3 END WHEN UPPER(T... |
| 7 | class_no | - | class_no | - | TRIM(s.class_no) AS class_no | TRIM(s.class_no) |
| 8 | derived | - | ship_builder_id | - | ship_builder_mapping.target_ship_builder_id AS ship_builder_id | ship_builder_mapping.target_ship_builder_id |
| 9 | derived | - | yard_country_id | - | country_mapping.target_country_id AS yard_country_id | country_mapping.target_country_id |
| 10 | keel_laid | - | keel_laid | - | s.keel_laid AS keel_laid | s.keel_laid |
| 11 | built_year | - | built_year | - | s.built_year AS built_year | s.built_year |
| 12 | build_date | - | build_on | - | CASE WHEN s.build_date IS NULL THEN NULL ELSE s.build_date::timestamp END AS build_on | CASE WHEN s.build_date IS NULL THEN NULL ELSE s.build_date::timestamp END |
| 13 | launched | - | launched | - | s.launched AS launched | s.launched |
| 14 | delivered | - | delivered | - | s.delivered AS delivered | s.delivered |
| 15 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 16 | derived | - | version | - | 1 AS version | 1 |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 18 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 19 | legacy_deleted_at, status | - | status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.status IS NULL OR TRIM(s.status) = '' THEN 0 WHEN UPPER(TRIM(s.status)) = 'ACTIVE' OR TRIM(s.status) = '1' THEN 0 WHEN UP... | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.status IS NULL OR TRIM(s.status) = '' THEN 0 WHEN UPPER(TRIM(s.status)) = 'ACTIVE' OR TRIM(s.status) = '1' THEN 0 WHEN UP... |
| 20 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 21 | legacy_updated_at | - | updated_at | - | COALESCE(s.legacy_updated_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, NOW()) |
| 22 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 23 | created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 24 | vessel_name, name | - | level | - | (ROW_NUMBER() OVER (ORDER BY COALESCE(TRIM(s.vessel_name), TRIM(s.name), 'UNKNOWN')) - 1)::numeric AS level | (ROW_NUMBER() OVER (ORDER BY COALESCE(TRIM(s.vessel_name), TRIM(s.name), 'UNKNOWN')) - 1)::numeric |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Category ID Mapping
**Output columns**: `source_category_id, target_category_id`
**migration.table_mappings**: `target_table='categories'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS source_category_id,
    vc.identifier::uuid AS target_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_categories'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### 2. Vessel Sub Category ID Mapping
**Output columns**: `source_sub_category_id, target_sub_category_id`
**migration.table_mappings**: `target_table='sub_categories'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vsc.id::bigint AS source_sub_category_id,
    vsc.identifier::uuid AS target_sub_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_sub_categories'
) AS vsc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'sub_categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vsc.id
);
```

### 3. Country ID Mapping
**Output columns**: `source_country_id, target_country_id`
**migration.table_mappings**: `target_table='countries'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_country_id,
    target_id AS target_country_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    c.id::bigint AS source_country_id,
    c.uuid::uuid AS target_country_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(
    id bigint,
    uuid uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'countries'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = c.id
);
```

### 4. Ship Builder ID Mapping
**Output columns**: `source_ship_builder_id, target_ship_builder_id`
**migration.table_mappings**: `target_table='ship_builders'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE ship_builder_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS source_ship_builder_id,
    target_id AS target_ship_builder_id
FROM migration.table_mappings
WHERE target_table = 'ship_builders'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    sb.identifier::uuid AS source_ship_builder_id,
    sb.identifier::uuid AS target_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.ship_builders WHERE identifier IS NOT NULL'
) AS sb(
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'ship_builders'
      AND tm.target_db = current_database()
      AND tm.source_id::uuid = sb.identifier
);
```

### 5. Vessel Details ID Mapping
**Output columns**: `legacy_vessel_id, vd.class_no, vessel_name, legacy_yard_country_id, legacy_ship_builder_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.class_no,
    vd.name AS vessel_name,
    vd.yard_country_id AS legacy_yard_country_id,
    vd.ship_builder AS legacy_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT vessel_id, class_no, name, yard_country_id, ship_builder, status, updated_at
     FROM public.vessel_details
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    class_no text,
    name text,
    yard_country_id bigint,
    ship_builder uuid,
    status text,
    updated_at timestamp
);
```

Full migration context: `04-migration-scripts/master/vessels_migration.sql`

## Validation

- Run `05-validation/master/vessels_validation.sql` if available
- Run `06-rollback/master/vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
