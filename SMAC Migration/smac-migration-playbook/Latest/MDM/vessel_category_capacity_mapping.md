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

- Unpivots SAC `vessel_categories` boolean capacity flags into one mapping row per (category, capacity) where flag is `true`
- `id` via `migration.resolve_target_id()` with composite source_id including `legacy_id`, capacity column, category UUID, and capacity UUID
- `category_id` from `identifier` preserved as `vessel.categories.id`; `capacity_id` from `capacity_id_mapping` (tags on `vessel.capacity`)
- `uom_id` from SAC `uom` column matched to `unit_of_measures` (DWT, TEU, CBM); fallback to zero UUID
- `status` mapped from SAC text `status` (ACTIVE/INACTIVE/DRAFT/DELETED → integer)
- Pre-migration duplicate UUID check on SAC `identifier` column
- Requires `vessel.categories`, `vessel.capacity`, and `unit_of_measures` migrated first

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
| 1 | `id`, capacity flags | bigint, boolean | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `legacy_id_capacityColumn_categoryId_capacityId` | Unpivot generates multiple rows per category; idempotent via `id_mappings` |
| 2 | capacity flags | boolean | `capacity_id` | uuid | Unpivot column name → `capacity_id_mapping` (match `vessel.capacity.tags`) | Only rows where capacity flag `IS NOT NULL` and `= true` |
| 3 | `identifier` | uuid | `category_id` | uuid | Join `category_id_mapping` on preserved `identifier` = `vessel.categories.id` | SAC `identifier` preserved as category UUID |
| 4 | `uom` | text | `uom_id` | uuid | Match `LOWER(TRIM(uom))` to `unit_of_measures` name or code; fallback zero UUID | Lookup: DWT, TEU, CBM from `public.unit_of_measures` |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | Direct copy from category row | Preserved from SAC source |
| 9 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Direct copy from category row | Preserved from SAC source |
| 10 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC soft-delete not migrated to mapping rows |
| 11 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | SAC `audit_info` not directly mapped; composite source_id in `id_mappings` |
| 13 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 14 | capacity flags | boolean | `tags` | text[] | Single-element array of capacity column name (`ballistic_capacity` → `ballast_capacity`) | Derived from unpivoted column name |
| 15 | `status` | text | `status` | integer | Map ACTIVE→0, INACTIVE→2, DRAFT→1, DELETED→3; default Active (0) | SAC text status to SMAC integer |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** Unpivoted capacity flags where `IS NULL` or `= false`; other `vessel_categories` attributes not referenced in unpivot staging.

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
