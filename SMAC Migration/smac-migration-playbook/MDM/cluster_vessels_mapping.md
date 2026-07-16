# Table Mapping: cluster_vessels → cluster_vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: cluster_vessels
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: cluster_vessels
- **Source Script**: `04-migration-scripts/master/cluster_vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.cluster_vessels`
- **New Path**: `smac_master_migration.vessel.cluster_vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.cluster_vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cluster_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_cluster_id`, `new_cluster_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | Check if any mappings | `vessel_details_identifier`, `new_vessel_id`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_fdl_dates_mapping` | FK lookup | `new_cluster_id`, `vessel_details_identifier`, `vf.effective_` | `migration.table_mappings` (see SQL) | `synergy_vessel` |

### `cluster_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_cluster_id, new_cluster_id
- **migration.table_mappings**: target_table=clusters

```sql
CREATE TEMP TABLE cluster_id_mapping AS
SELECT
    source_id::uuid as legacy_cluster_id,
    target_id::uuid as new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### `vessel_id_mapping`

- **Purpose**: Check if any mappings
- **Output columns**: vessel_details_identifier, new_vessel_id, new_vessel_revision_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.identifier as vessel_details_identifier,
    tm_vessel.target_id as new_vessel_id,
    vr.id as new_vessel_revision_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.source_id = vd.vessel_id::text
    AND tm_vessel.target_table = 'vessels'
    AND tm_vessel.target_db = current_database()
LEFT JOIN vessel.vessel_revisions vr
    ON vr.id = vd.identifier
WHERE tm_vessel.target_id IS NOT NULL
  AND vr.id IS NOT NULL;
```

### `vessel_fdl_dates_mapping`

- **Output columns**: new_cluster_id, vessel_details_identifier, vf.effective_
- **migration.table_mappings**: target_table=clusters
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_fdl_dates_mapping AS
SELECT DISTINCT ON (tm_cluster.target_id, vd.identifier)
    tm_cluster.target_id AS new_cluster_id,
    vd.identifier AS vessel_details_identifier,
    vf.effective_from_date AS effective_from_date,
    vf.handover_date AS handover_date
FROM dblink('synergy_vessel',
    'SELECT cluster_id, vessel_id, effective_from_date, handover_date
     FROM public.vessel_fdl
     WHERE cluster_id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vf(
    cluster_id uuid,
    vessel_id uuid,
    effective_from_date timestamp,
    handover_date timestamp
)
LEFT JOIN migration.table_mappings tm_cluster
    ON tm_cluster.source_id = vf.cluster_id::text
    AND tm_cluster.target_table = 'clusters'
    AND tm_cluster.target_db = current_database()
LEFT JOIN dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_details WHERE identifier IS NOT NULL'
) AS vd(identifier uuid)
    ON vd.identifier = vf.vessel_id
WHERE tm_cluster.target_id IS NOT NULL
  AND vd.identifier IS NOT NULL
ORDER BY tm_cluster.target_id, vd.identifier, vf.effective_from_date DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'cluster_vessels'::VARCHAR(100), legacy_data.id::text, current_... |
| 2 | derived | - | cluster_id | - | c_map.new_cluster_id AS cluster_id | c_map.new_cluster_id |
| 3 | derived | - | vessel_id | - | v_map.new_vessel_id AS vessel_id | v_map.new_vessel_id |
| 4 | effective_ | - | effective_from | - | vf_dates.effective_ | vf_dates.effective_ |
| 5 | - | - | effective_to | - | See source script | See source script |
| 6 | - | - | tenant_id | - | See source script | See source script |
| 7 | - | - | parent_id | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | created_at | - | See source script | See source script |
| 10 | - | - | updated_at | - | See source script | See source script |
| 11 | - | - | deleted_at | - | See source script | See source script |
| 12 | - | - | archived_at | - | See source script | See source script |
| 13 | - | - | audit_info | - | See source script | See source script |
| 14 | - | - | level | - | See source script | See source script |
| 15 | - | - | vessel_revision_id | - | See source script | See source script |
| 16 | - | - | tags | - | See source script | See source script |
| 17 | - | - | status | - | See source script | See source script |
| 18 | - | - | workflow_status | - | See source script | See source script |
| 19 | - | - | defined_by | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.clusters`
- `vessel.vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cluster ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_cluster_id, new_cluster_id`
**migration.table_mappings**: `target_table='clusters'`

```sql
CREATE TEMP TABLE cluster_id_mapping AS
SELECT
    source_id::uuid as legacy_cluster_id,
    target_id::uuid as new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### 2. Vessel ID Mapping
**Purpose**: Check if any mappings
**Output columns**: `vessel_details_identifier, new_vessel_id, new_vessel_revision_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.identifier as vessel_details_identifier,
    tm_vessel.target_id as new_vessel_id,
    vr.id as new_vessel_revision_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.source_id = vd.vessel_id::text
    AND tm_vessel.target_table = 'vessels'
    AND tm_vessel.target_db = current_database()
LEFT JOIN vessel.vessel_revisions vr
    ON vr.id = vd.identifier
WHERE tm_vessel.target_id IS NOT NULL
  AND vr.id IS NOT NULL;
```

### 3. Vessel Fdl Dates ID Mapping
**Output columns**: `new_cluster_id, vessel_details_identifier, vf.effective_`
**migration.table_mappings**: `target_table='clusters'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_fdl_dates_mapping AS
SELECT DISTINCT ON (tm_cluster.target_id, vd.identifier)
    tm_cluster.target_id AS new_cluster_id,
    vd.identifier AS vessel_details_identifier,
    vf.effective_from_date AS effective_from_date,
    vf.handover_date AS handover_date
FROM dblink('synergy_vessel',
    'SELECT cluster_id, vessel_id, effective_from_date, handover_date
     FROM public.vessel_fdl
     WHERE cluster_id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vf(
    cluster_id uuid,
    vessel_id uuid,
    effective_from_date timestamp,
    handover_date timestamp
)
LEFT JOIN migration.table_mappings tm_cluster
    ON tm_cluster.source_id = vf.cluster_id::text
    AND tm_cluster.target_table = 'clusters'
    AND tm_cluster.target_db = current_database()
LEFT JOIN dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_details WHERE identifier IS NOT NULL'
) AS vd(identifier uuid)
    ON vd.identifier = vf.vessel_id
WHERE tm_cluster.target_id IS NOT NULL
  AND vd.identifier IS NOT NULL
ORDER BY tm_cluster.target_id, vd.identifier, vf.effective_from_date DESC;
```

Full migration context: `04-migration-scripts/master/cluster_vessels_migration.sql`

## Validation

- Run `05-validation/master/cluster_vessels_validation.sql` if available
- Run `06-rollback/master/cluster_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
