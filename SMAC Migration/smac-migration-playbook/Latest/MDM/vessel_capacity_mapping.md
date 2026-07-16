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

- Legacy: `synergy_vessel.public.vessel_particulars` unpivoted (13 capacity columns) → `vessel.vessel_capacity`
- `id` via `migration.resolve_target_id()` with composite `source_id` (`id|column_name`); `p_target_id = NULL`
- `vessel_id` via `vessel_details` → `migration.table_mappings` (vessels)
- `capacity_id` via `capacity_id_mapping` (column name → `vessel.capacity.tags`)
- `uom_id` via `vessel_category_capacity_mapping` on vessel category + capacity
- Filter per branch: `vessel_id`, `identifier`, and capacity value NOT NULL; final INSERT requires valid vessel mapping
- Migrate ALL rows including deleted status values
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
| 1 | `id, identifier, capacity column` | bigint, uuid, numeric | `id` | uuid | `migration.resolve_target_id()` — composite source_id; `p_target_id = NULL` | One row per non-null capacity column |
| 2 | `capacity column name` | — | `capacity_id` | uuid | Map via `capacity_id_mapping` by capacity tag name | FK to `vessel.capacity` |
| 3 | `vessel_id` | bigint | `vessel_id` | uuid | `vessels_id_mapping` via `vessel_details` | FK lookup |
| 4 | `vessel_id, capacity_id` | bigint, uuid | `uom_id` | uuid | `vessel_category_capacity_mapping` on category + capacity | FK lookup |
| 5 | `capacity, ballistic_capacity, grain_capacity, etc.` | numeric | `value` | numeric(18,2) | Cast from unpivoted source column | 13 capacity types unpivoted |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp with time zone | `COALESCE(created_at, NOW())` with infinity guard | NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp with time zone | `COALESCE(updated_at, NOW())` with infinity guard | Direct copy with fallback |
| 11 | `—` | — | `deleted_at` | timestamp with time zone | `NULL` | Not set from source |
| 12 | `—` | — | `archived_at` | timestamp with time zone | `NULL` | Not in SAC source |
| 13 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` + approval field extraction | Standardized SMAC structure |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 15 | `capacity column name` | — | `tags` | text[] | `ARRAY[capacity_column_name]` | Identifies capacity type |
| 16 | `status` | text | `status` | integer | ACTIVE→0, INACTIVE→2, DRAFT→1, DELETED→3 | String status mapping |
| 17 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 18 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |

**SAC columns not migrated:** Non-capacity `vessel_particulars` columns migrated separately in `vessel_particulars` migration.

**SMAC columns not migrated:** None beyond defaults above.

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
