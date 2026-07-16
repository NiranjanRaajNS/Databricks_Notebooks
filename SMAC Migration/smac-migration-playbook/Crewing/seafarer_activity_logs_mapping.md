# Table Mapping: seafarer_activity_logs → seafarer_activity_logs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_logs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_activity_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_activity_logs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_logs`
- **New Path**: `smac_crewing_migration.public.seafarer_activity_logs`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Activity Logs (`seafarer_activity_logs` → `seafarer_activity_logs`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_activity_logs preserving UUID id. Maps vessel_id and rank_id from bigint to UUID via smac_master_migration mapping tables. Calculates duration_days from from_date and to_date. Direct copy of audit_info JSONB.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_activity_logs` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `activity_log_types`, `activity_log_sub_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `vessel_name_lookup` | FK lookup | `vessel_id`, `vessel_name` | - | `smac_master_migration` |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    tm.source_id::bigint as legacy_id,
    tm.target_id as new_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE target_table = 'vessels'
          AND source_id IS NOT NULL
          AND target_id IS NOT NULL
    $dblink_query$
) AS tm(source_id text, target_id uuid)
WHERE tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL
  AND tm.source_id ~ '^[0-9]+$';
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT DISTINCT
    r.id::bigint as legacy_id,
    r.identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
WHERE r.identifier IS NOT NULL;
```

### `vessel_name_lookup`

- **Output columns**: vessel_id, vessel_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_name_lookup AS
SELECT
    v.id as vessel_id,
    v.name as vessel_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.vessels WHERE name IS NOT NULL'
) AS v(id uuid, name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_activity_logs'::VARCHAR(100), legacy_data.id::text, current_database()::text::VA... |
| 2 | seafarer_id | - | seafarer_id | - | legacy_data.seafarer_id as seafarer_id | legacy_data.seafarer_id |
| 3 | type_id | - | activity_type_id | - | legacy_data.type_id as activity_type_id | legacy_data.type_id |
| 4 | sub_type_id | - | activity_sub_type_id | - | legacy_data.sub_type_id as activity_sub_type_id | legacy_data.sub_type_id |
| 5 | other_activity | - | other_activity | - | TRIM(legacy_data.other_activity) as other_activity | TRIM(legacy_data.other_activity) |
| 6 | derived | - | vessel_id | - | vessel_map.new_id AS vessel_id | vessel_map.new_id |
| 7 | derived | - | vessel_name | - | vessel_name_lookup.vessel_name as vessel_name | vessel_name_lookup.vessel_name |
| 8 | vessel_imo | - | vessel_imo | - | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::text, 10)::varchar(10) ELSE NULL END AS vessel_imo | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::text, 10)::varchar(10) ELSE NULL END |
| 9 | derived | - | rank_id | - | rank_map.new_id AS rank_id | rank_map.new_id |
| 10 | derived | - | from_date | - | legacy_data. | legacy_data. |
| 11 | - | - | to_date | - | See source script | See source script |
| 12 | - | - | duration_days | - | See source script | See source script |
| 13 | - | - | source | - | See source script | See source script |
| 14 | - | - | is_manual | - | See source script | See source script |
| 15 | - | - | reference_entity | - | See source script | See source script |
| 16 | - | - | reference_id | - | See source script | See source script |
| 17 | - | - | remarks | - | See source script | See source script |
| 18 | - | - | tenant_id | - | See source script | See source script |
| 19 | - | - | created_at | - | See source script | See source script |
| 20 | - | - | updated_at | - | See source script | See source script |
| 21 | - | - | archived_at | - | See source script | See source script |
| 22 | - | - | deleted_at | - | See source script | See source script |
| 23 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    tm.source_id::bigint as legacy_id,
    tm.target_id as new_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE target_table = 'vessels'
          AND source_id IS NOT NULL
          AND target_id IS NOT NULL
    $dblink_query$
) AS tm(source_id text, target_id uuid)
WHERE tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL
  AND tm.source_id ~ '^[0-9]+$';
```

### 2. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT DISTINCT
    r.id::bigint as legacy_id,
    r.identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
WHERE r.identifier IS NOT NULL;
```

### 3. Vessel Name ID Mapping
**Output columns**: `vessel_id, vessel_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_name_lookup AS
SELECT
    v.id as vessel_id,
    v.name as vessel_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.vessels WHERE name IS NOT NULL'
) AS v(id uuid, name text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_activity_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_activity_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_activity_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
