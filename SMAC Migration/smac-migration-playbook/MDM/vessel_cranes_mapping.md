# Table Mapping: vessels_cranes → vessel_cranes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessels_cranes
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_cranes
- **Source Script**: `04-migration-scripts/master/vessel_cranes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessels_cranes`
- **New Path**: `smac_master_migration.vessel.vessel_cranes`

## Business Key

- **Composite Key**: (`vessel_id`, `name`)
- **Source (orchestration)**: Vessel Cranes (`vessels_cranes` → `vessel_cranes`)

## Migration Notes

- Generate new UUIDs for id (source table has no identifier/uuid column)
- Map vesselsid (bigint) → vessel_id (uuid) via vessel_details → migration.table_mappings (vessels)
- Map crane (bigint) → crane_type_id (uuid) via migration.table_mappings (crane_types)
- Source table has minimal columns: id, vesselsid, crane, crane_capacity
- Target table: vessel_id, crane_id, crane_type_id, cranes_nos, level, parent_id, tags, etc.
- crane_capacity stored in audit_info->>'legacy_crane_capacity' (target has no capacity column)
- Target columns not in source (crane_id, cranes_nos, level, parent_id, tags) set to NULL
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessels to be migrated first
- Migrates vessels_cranes to vessel_cranes. Source table has minimal columns: id, vesselsid, crane, crane_capacity. Generates new UUIDs for id (no identifier/uuid in source). Maps vesselsid (bigint) to vessel_id (uuid) via vessel_details → migration.table_mappings (vessels). Maps crane (bigint) to crane_type_id (uuid) via migration.table_mappings (crane_types) if exists. crane_capacity stored in audit_info->>'legacy_crane_capacity' since target has no capacity column. Target columns not in source (crane_id, cranes_nos, level, parent_id, tags, status, timestamps) are set to NULL or defaults. Uses standardized SMAC audit_info structure. Requires vessels and crane_types tables to be migrated first.

## Special Considerations

- Includes all rows (per Rule 2.6 - no deleted_at filter)
- Script performs `TRUNCATE TABLE vessel.vessel_cranes` before insert (full table reload).
- Orchestration dependencies: `vessels`, `crane_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | Check if any m | `vessel_details_id`, `vessel_legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `crane_type_id_mapping` | FK lookup | `legacy_crane_id`, `new_crane_type_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Purpose**: Check if any m
- **Output columns**: vessel_details_id, vessel_legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    tm.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vesselsid
     FROM public.vessels_cranes
     WHERE vesselsid IS NOT NULL'
) AS vc(vesselsid bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vc.vesselsid
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### `crane_type_id_mapping`

- **Output columns**: legacy_crane_id, new_crane_type_id
- **migration.table_mappings**: target_table=crane_types

```sql
CREATE TEMP TABLE crane_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_crane_id,
    target_id AS new_crane_type_id
FROM migration.table_mappings
WHERE target_table = 'crane_types'
  AND target_db = current_database()
  AND source_id ~ '^\d+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessels_cranes'::VARCHAR(100), md.legacy_id::text, current_database()::text::VARCHAR(100), ... |
| 2 | derived | - | vessel_id | - | md.new_vessel_id AS vessel_id | md.new_vessel_id |
| 3 | - | - | crane_id | - | NULL | NULL::uuid |
| 4 | - | - | cranes_nos | - | NULL | NULL::integer |
| 5 | - | - | level | - | NULL | NULL::integer |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 11 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 12 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 13 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |
| 14 | derived | - | crane_type_id | - | md.new_crane_type_id AS crane_type_id | md.new_crane_type_id |
| 15 | - | - | tags | - | NULL | NULL::text[] |
| 16 | derived | - | status | - | 0 AS status | 0 |
| 17 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 18 | derived | - | defined_by | - | 0 AS defined_by | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Purpose**: Check if any m
**Output columns**: `vessel_details_id, vessel_legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    tm.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vesselsid
     FROM public.vessels_cranes
     WHERE vesselsid IS NOT NULL'
) AS vc(vesselsid bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vc.vesselsid
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Crane Type ID Mapping
**Output columns**: `legacy_crane_id, new_crane_type_id`
**migration.table_mappings**: `target_table='crane_types'`

```sql
CREATE TEMP TABLE crane_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_crane_id,
    target_id AS new_crane_type_id
FROM migration.table_mappings
WHERE target_table = 'crane_types'
  AND target_db = current_database()
  AND source_id ~ '^\d+$';
```

Full migration context: `04-migration-scripts/master/vessel_cranes_migration.sql`

## Validation

- Run `05-validation/master/vessel_cranes_validation.sql` if available
- Run `06-rollback/master/vessel_cranes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
