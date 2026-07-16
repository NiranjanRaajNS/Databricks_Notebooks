# Table Mapping: vessel_particulars → vessel_capacity

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_particulars
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_capacity
- **Source Script**: `04-migration-scripts/master/vessel_capacity_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_particulars`
- **New Path**: `smac_master_migration.vessel.vessel_capacity`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Capacity Types (`vessel_particulars` → `capacity`)

## Migration Notes

- Extracts capacity values from vessel_particulars capacity columns
- Creates one row per capacity value per vessel
- Maps vessel_id from vessel_particulars.vessel_id (bigint) to vessel.vessels.id (uuid)
- Maps capacity_id from capacity column name to vessel.capacity.id (via tags)
- Uses migration.resolve_target_id() for idempotent UUID generation
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessels and vessel.capacity to be migrated first
- Special transformation: Extract columns ending with '_capacity' from vessel_particulars. Creates one row per capacity column in vessel.capacity. This migration creates reference/master data from column names, not actual data values. Each capacity type gets a unique code, name (uppercase with spaces), and tags array. Only fuel_oil_capacity is marked as mandatory.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_capacity` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `capacity_id_mapping` | FK lookup | `capacity_column_name`, `capacity_id` | - | - |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `capacity_id_mapping`

- **Output columns**: capacity_column_name, capacity_id

```sql
CREATE TEMP TABLE capacity_id_mapping AS
SELECT
    'capacity' AS capacity_column_name,
    c.id AS capacity_id
FROM vessel.capacity c
WHERE 'capacity' = ANY(c.tags)
UNION ALL
SELECT 'ballast_capacity', c.id FROM vessel.capacity c WHERE 'ballast_capacity' = ANY(c.tags)
UNION ALL
SELECT 'grain_capacity', c.id FROM vessel.capacity c WHERE 'grain_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fuel_oil_capacity', c.id FROM vessel.capacity c WHERE 'fuel_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lubricating_oil_capacity', c.id FROM vessel.capacity c WHERE 'lubricating_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fresh_water_capacity', c.id FROM vessel.capacity c WHERE 'fresh_water_capacity' = ANY(c.tags)
UNION ALL
SELECT 'gas_capacity', c.id FROM vessel.capacity c WHERE 'gas_capacity' = ANY(c.tags)
UNION ALL
SELECT 'liquid_capacity', c.id FROM vessel.capacity c WHERE 'liquid_capacity' = ANY(c.tags)
UNION ALL
SELECT 'teu_capacity', c.id FROM vessel.capacity c WHERE 'teu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'ceu_capacity', c.id FROM vessel.capacity c WHERE 'ceu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'bale_capacity', c.id FROM vessel.capacity c WHERE 'bale_capacity' = ANY(c.tags)
U...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_particulars'::VARCHAR(100), LEFT((svc.legacy_id::text || '_' || svc.capacity_column_... |
| 2 | derived | - | capacity_id | - | cap_map.capacity_id | cap_map.capacity_id |
| 3 | derived | - | vessel_id | - | v_mapping.target_id AS vessel_id | v_mapping.target_id |
| 4 | derived | - | uom_id | - | vccm.uom_id | vccm.uom_id |
| 5 | derived | - | value | - | svc.capacity_value | svc.capacity_value |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | derived | - | created_at | - | CASE WHEN svc.created_at IS NULL THEN NOW() WHEN svc.created_at = 'infinity'::timestamp OR svc.created_at = '-infinity'::timestamp OR svc.created_at > '9999-12-31'::timestamp TH... | CASE WHEN svc.created_at IS NULL THEN NOW() WHEN svc.created_at = 'infinity'::timestamp OR svc.created_at = '-infinity'::timestamp OR svc.created_at > '9999-12-31'::timestamp TH... |
| 10 | derived | - | updated_at | - | CASE WHEN svc.updated_at IS NULL OR svc.updated_at = 'infinity'::timestamp OR svc.updated_at = '-infinity'::timestamp OR svc.updated_at > '9999-12-31'::timestamp THEN CASE WHEN ... | CASE WHEN svc.updated_at IS NULL OR svc.updated_at = 'infinity'::timestamp OR svc.updated_at = '-infinity'::timestamp OR svc.updated_at > '9999-12-31'::timestamp THEN CASE WHEN ... |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 12 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, CASE WHEN svc.audit_info IS NOT NULL AND svc.aud... |
| 14 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 15 | derived | - | tags | - | ARRAY[svc.capacity_column_name] AS tags | ARRAY[svc.capacity_column_name] |
| 16 | derived | - | status | - | CASE WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'INACTIVE' THEN 2 WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'DR... | CASE WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'INACTIVE' THEN 2 WHEN UPPER(TRIM(COALESCE(svc.status, ''))) = 'DR... |
| 17 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 18 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.capacity`
- `vessel.vessel_category_capacity_mapping`
- `vessel.vessels`
- `vessel_category_capacity_mapping`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Capacity ID Mapping
**Output columns**: `capacity_column_name, capacity_id`

```sql
CREATE TEMP TABLE capacity_id_mapping AS
SELECT
    'capacity' AS capacity_column_name,
    c.id AS capacity_id
FROM vessel.capacity c
WHERE 'capacity' = ANY(c.tags)
UNION ALL
SELECT 'ballast_capacity', c.id FROM vessel.capacity c WHERE 'ballast_capacity' = ANY(c.tags)
UNION ALL
SELECT 'grain_capacity', c.id FROM vessel.capacity c WHERE 'grain_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fuel_oil_capacity', c.id FROM vessel.capacity c WHERE 'fuel_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lubricating_oil_capacity', c.id FROM vessel.capacity c WHERE 'lubricating_oil_capacity' = ANY(c.tags)
UNION ALL
SELECT 'fresh_water_capacity', c.id FROM vessel.capacity c WHERE 'fresh_water_capacity' = ANY(c.tags)
UNION ALL
SELECT 'gas_capacity', c.id FROM vessel.capacity c WHERE 'gas_capacity' = ANY(c.tags)
UNION ALL
SELECT 'liquid_capacity', c.id FROM vessel.capacity c WHERE 'liquid_capacity' = ANY(c.tags)
UNION ALL
SELECT 'teu_capacity', c.id FROM vessel.capacity c WHERE 'teu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'ceu_capacity', c.id FROM vessel.capacity c WHERE 'ceu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'bale_capacity', c.id FROM vessel.capacity c WHERE 'bale_capacity' = ANY(c.tags)
UNION ALL
SELECT 'feu_capacity', c.id FROM vessel.capacity c WHERE 'feu_capacity' = ANY(c.tags)
UNION ALL
SELECT 'lifeboat_capacity', c.id FROM vessel.capacity c WHERE 'lifeboat_capacity' = ANY(c.tags);
```

Full migration context: `04-migration-scripts/master/vessel_capacity_migration.sql`

## Validation

- Run `05-validation/master/vessel_capacity_validation.sql` if available
- Run `06-rollback/master/vessel_capacity_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
