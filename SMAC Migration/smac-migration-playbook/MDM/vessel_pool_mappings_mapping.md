# Table Mapping: vessel_pool_mappings → vessel_pool_mappings

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_pool_mappings
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_pool_mappings
- **Source Script**: `04-migration-scripts/master/vessel_pool_mappings_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_pool_mappings`
- **New Path**: `smac_master_migration.vessel.vessel_pool_mappings`

## Business Key

- **Composite Key**: (`vessel_id`, `vessel_pool_id`)
- **Source (orchestration)**: Vessel Pool Mappings (`vessel_pool_mappings` → `vessel_pool_mappings`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_pool_mappings from synergy_master.public.vessel_pool_mappings to smac_master_migration.vessel.vessel_pool_mappings. Preserves legacy UUID as target id (Pattern A). Maps vessel_id from integer to uuid via migration.table_mappings (vessels table). Maps vessel_pool_id from uuid to uuid via migration.table_mappings (vessel_pools table). Sets VesselId1 to same value as vessel_id. Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Stores created_by_id, updated_by_id, deleted_by_id in audit_info JSONB. Uses standardized SMAC audit_info structure without legacy_id (since UUID is preserved). Requires vessels and vessel_pools tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_pool_mappings` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_pools`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | Check for duplicate UUIDs in source table | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_pool_id_mapping` | Chec | `legacy_pool_id`, `new_pool_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_vessel_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `vessel_pool_id_mapping`

- **Purpose**: Chec
- **Output columns**: legacy_pool_id, new_pool_id
- **migration.table_mappings**: target_table=vessel_pools

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT
    source_id::uuid AS legacy_pool_id,
    target_id AS new_pool_id
FROM migration.table_mappings
WHERE target_table = 'vessel_pools'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_pool_mappings'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | derived | - | vessel_id | - | v_map.new_vessel_id as vessel_id | v_map.new_vessel_id |
| 3 | derived | - | vessel_pool_id | - | vp_map.new_pool_id as vessel_pool_id | vp_map.new_pool_id |
| 4 | derived | - | effective_from | - | effective_ | effective_ |
| 5 | - | - | effective_until | - | See source script | See source script |
| 6 | - | - | "VesselId1" | - | See source script | See source script |
| 7 | - | - | tenant_id | - | See source script | See source script |
| 8 | - | - | parent_id | - | See source script | See source script |
| 9 | - | - | level | - | See source script | See source script |
| 10 | - | - | version | - | See source script | See source script |
| 11 | - | - | defined_by | - | See source script | See source script |
| 12 | - | - | workflow_status | - | See source script | See source script |
| 13 | - | - | status | - | See source script | See source script |
| 14 | - | - | created_at | - | See source script | See source script |
| 15 | - | - | updated_at | - | See source script | See source script |
| 16 | - | - | deleted_at | - | See source script | See source script |
| 17 | - | - | archived_at | - | See source script | See source script |
| 18 | - | - | audit_info | - | See source script | See source script |
| 19 | - | - | tags | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_vessel_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Vessel Pool ID Mapping
**Purpose**: Chec
**Output columns**: `legacy_pool_id, new_pool_id`
**migration.table_mappings**: `target_table='vessel_pools'`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT
    source_id::uuid AS legacy_pool_id,
    target_id AS new_pool_id
FROM migration.table_mappings
WHERE target_table = 'vessel_pools'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_pool_mappings_migration.sql`

## Validation

- Run `05-validation/master/vessel_pool_mappings_validation.sql` if available
- Run `06-rollback/master/vessel_pool_mappings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
