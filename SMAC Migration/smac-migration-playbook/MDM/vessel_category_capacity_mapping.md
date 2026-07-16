# Table Mapping: vessel_categories → vessel_category_capacity_mapping

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_category_capacity_mapping
- **Source Script**: `04-migration-scripts/master/vessel_category_capacity_mapping_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_categories`
- **New Path**: `smac_master_migration.vessel.vessel_category_capacity_mapping`

## Business Key

- **Composite Key**: (`category_id`, `capacity_id`)
- **Source (orchestration)**: Vessel Category Capacity Mapping (`vessel_categories` → `vessel_category_capacity_mapping`)

## Migration Notes

- Creates mapping records for each vessel category that has capacity flags set to true
- Maps category_id from vessel_categories.identifier to vessel.categories.id
- Maps capacity_id from capacity column name to vessel.capacity.id (via tags)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.categories and vessel.capacity to be migrated first

## Special Considerations

- Uses migration.resolve_target_id() with composite source IDs for unpivot scenario
- Script performs `TRUNCATE TABLE vessel.vessel_category_capacity_mapping` before insert (full table reload).
- Orchestration dependencies: `vessel_categories`, `capacity`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `category_id_mapping` | FK lookup | `legacy_identifier`, `new_category_id` | - | `synergy_vessel` |
| `uom_id_mapping` | FK lookup | `uom_name_lower`, `uom_code_lower`, `uom_id` | - | - |
| `capacity_id_mapping` | FK lookup | `capacity_column_name`, `capacity_id` | - | - |

### `category_id_mapping`

- **Output columns**: legacy_identifier, new_category_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    legacy_data.identifier::uuid AS legacy_identifier,
    cat.id AS new_category_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_categories WHERE identifier IS NOT NULL'
) AS legacy_data(identifier uuid)
JOIN vessel.categories cat ON cat.id = legacy_data.identifier;
```

### `uom_id_mapping`

- **Output columns**: uom_name_lower, uom_code_lower, uom_id

```sql
CREATE TEMP TABLE uom_id_mapping AS
SELECT DISTINCT
    LOWER(TRIM(uom.name)) AS uom_name_lower,
    LOWER(TRIM(uom.code)) AS uom_code_lower,
    uom.id AS uom_id
FROM public.unit_of_measures uom
WHERE uom.code IN ('DWT', 'TEU', 'CBM');
```

### `capacity_id_mapping`

- **Output columns**: capacity_column_name, capacity_id

```sql
CREATE TEMP TABLE capacity_id_mapping AS
SELECT
    'grain_capacity' AS capacity_column_name,
    c.id AS capacity_id
FROM vessel.capacity c
WHERE 'grain_capacity' = ANY(c.tags)
UNION ALL
SELECT 'bale_capacity', c.id FROM vessel.capacity c WHERE 'bale_capacity' = ANY(c.tags)
UNION ALL
SELECT 'liquid_capacity', c.id FROM vessel.capacity c WHERE 'liquid_capacity' = ANY(c.tags)
UNION ALL
SELECT 'gas_capacity', c.id FROM vessel.capacity c WHERE 'gas_capacity' = ANY(c.tags)
UNION ALL
SELECT 'teu_capacity', c.id FROM vessel.capacity c WHERE 'teu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fuel_oil_capacity', c.id FROM vessel.capacity c WHERE 'fuel_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'ceu_capacity', c.id FROM vessel.capacity c WHERE 'ceu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'capacity', c.id FROM vessel.capacity c WHERE 'capacity' = ANY(c.tags)
UNION ALL
SELECT 'ballistic_capacity', c.id FROM vessel.capacity c WHERE 'ballast_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lubricating_oil_capacity', c.id FROM vessel.capacity c WHERE 'lubricating_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fresh_water_capacity', c.id FROM vessel.capacity c WHERE 'fresh_water_capacity' = ANY(c.tags)...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (cat_map.new_category_id, cap_map.capacity_id) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_categories'::VARCHAR(100)... |
| 2 | derived | - | capacity_id | - | cap_map.capacity_id | cap_map.capacity_id |
| 3 | derived | - | category_id | - | cat_map.new_category_id AS category_id | cat_map.new_category_id |
| 4 | derived | - | uom_id | - | COALESCE( (SELECT uom_id FROM uom_id_mapping WHERE uom_name_lower = LOWER(TRIM(scc.uom)) OR uom_code_lower = LOWER(TRIM(scc.uom)) LIMIT 1), '00000000-0000-0000-0000-000000000000... | COALESCE( (SELECT uom_id FROM uom_id_mapping WHERE uom_name_lower = LOWER(TRIM(scc.uom)) OR uom_code_lower = LOWER(TRIM(scc.uom)) LIMIT 1), '00000000-0000-0000-0000-000000000000... |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | derived | - | created_at | - | scc.created_at AS created_at | scc.created_at |
| 9 | derived | - | updated_at | - | scc.updated_at AS updated_at | scc.updated_at |
| 10 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 11 | - | - | archived_at | - | NULL | NULL::timestamp |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 13 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 14 | derived | - | tags | - | ARRAY[ CASE WHEN scc.capacity_column_name = 'ballistic_capacity' THEN 'ballast_capacity' ELSE scc.capacity_column_name END ] AS tags | ARRAY[ CASE WHEN scc.capacity_column_name = 'ballistic_capacity' THEN 'ballast_capacity' ELSE scc.capacity_column_name END ] |
| 15 | derived | - | status | - | CASE WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'INACTIVE' THEN 2 WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'DR... | CASE WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'INACTIVE' THEN 2 WHEN UPPER(TRIM(COALESCE(scc.status, ''))) = 'DR... |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `capacity`
- `vessel.capacity`
- `vessel.categories`
- `vessel_categories`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Category ID Mapping
**Output columns**: `legacy_identifier, new_category_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    legacy_data.identifier::uuid AS legacy_identifier,
    cat.id AS new_category_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_categories WHERE identifier IS NOT NULL'
) AS legacy_data(identifier uuid)
JOIN vessel.categories cat ON cat.id = legacy_data.identifier;
```

### 2. Uom ID Mapping
**Output columns**: `uom_name_lower, uom_code_lower, uom_id`

```sql
CREATE TEMP TABLE uom_id_mapping AS
SELECT DISTINCT
    LOWER(TRIM(uom.name)) AS uom_name_lower,
    LOWER(TRIM(uom.code)) AS uom_code_lower,
    uom.id AS uom_id
FROM public.unit_of_measures uom
WHERE uom.code IN ('DWT', 'TEU', 'CBM');
```

### 3. Capacity ID Mapping
**Output columns**: `capacity_column_name, capacity_id`

```sql
CREATE TEMP TABLE capacity_id_mapping AS
SELECT
    'grain_capacity' AS capacity_column_name,
    c.id AS capacity_id
FROM vessel.capacity c
WHERE 'grain_capacity' = ANY(c.tags)
UNION ALL
SELECT 'bale_capacity', c.id FROM vessel.capacity c WHERE 'bale_capacity' = ANY(c.tags)
UNION ALL
SELECT 'liquid_capacity', c.id FROM vessel.capacity c WHERE 'liquid_capacity' = ANY(c.tags)
UNION ALL
SELECT 'gas_capacity', c.id FROM vessel.capacity c WHERE 'gas_capacity' = ANY(c.tags)
UNION ALL
SELECT 'teu_capacity', c.id FROM vessel.capacity c WHERE 'teu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fuel_oil_capacity', c.id FROM vessel.capacity c WHERE 'fuel_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'ceu_capacity', c.id FROM vessel.capacity c WHERE 'ceu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'capacity', c.id FROM vessel.capacity c WHERE 'capacity' = ANY(c.tags)
UNION ALL
SELECT 'ballistic_capacity', c.id FROM vessel.capacity c WHERE 'ballast_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lubricating_oil_capacity', c.id FROM vessel.capacity c WHERE 'lubricating_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fresh_water_capacity', c.id FROM vessel.capacity c WHERE 'fresh_water_capacity' = ANY(c.tags)
UNION ALL
SELECT 'feu_capacity', c.id FROM vessel.capacity c WHERE 'feu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lifeboat_capacity', c.id FROM vessel.capacity c WHERE 'lifeboat_capacity' = ANY(c.tags);
```

Full migration context: `04-migration-scripts/master/vessel_category_capacity_mapping_migration.sql`

## Validation

- Run `05-validation/master/vessel_category_capacity_mapping_validation.sql` if available
- Run `06-rollback/master/vessel_category_capacity_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
