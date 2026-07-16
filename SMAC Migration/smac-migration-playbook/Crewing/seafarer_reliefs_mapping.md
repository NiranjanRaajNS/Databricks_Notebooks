# Table Mapping: reliefs → seafarer_reliefs

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: reliefs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_reliefs
- **Source Script**: `04-migration-scripts/crewing/seafarer_reliefs_migration.sql`

- **Legacy Path**: `synergy_manning.public.reliefs`
- **New Path**: `smac_crewing_migration.public.seafarer_reliefs`

## Business Key

- **Composite Key**: (`seafarer_id`, `vessel_id`)
- **Source (orchestration)**: Reliefs (`reliefs` → `seafarer_reliefs`)

## Migration Notes

- Only migrates reliefs that are present in relief_summary (planned_relief_id or onboard_relief_id)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires relief_summary table to exist (created by seafarer_vessel_assignments migration)
- Migrates reliefs to seafarer_reliefs. Maps seafarer_id (bigint) to seafarer_id (uuid) via migration.table_mappings. Maps vessel_id (bigint) to vessel_id (uuid) via migration.table_mappings. Maps position_id (bigint) to position_id (uuid) via positions.identifier. Generates new UUIDs for id column. Requires seafarers, vessels, and positions tables to be migrated first.

## Special Considerations

- IMPORTANT: Run schema discovery first to verify identifier/uuid columns exist
- Filter numeric source_ids INSIDE dblink query AND include target_db filter
- Script performs `TRUNCATE TABLE public.seafarer_reliefs` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `positions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 15

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | Check for duplicate UUIDs in so | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_imo_mapping` | FK lookup | `vessel_id`, `imo_number` | - | `smac_master_migration` |
| `relief_type_id_mapping` | FK lookup | `relief_type_name_normalized`, `relief_type_name`, `relief_type_id`, `mapped_type` | - | `smac_master_migration` |
| `relief_state_id_mapping` | FK lookup | `relief_state_code`, `relief_state_id` | - | `smac_master_migration` |
| `relief_seafarer_departures_lookup` | Create vessel lookup mapping by IMO number | `relief_id`, `seafarer_id`, `status_normalized` | - | `synergy_manning` |
| `offsigner_assignment_mapping` | Create relief_type lookup mapping from master data (crewing.relief_types) | `legacy_relief_id`, `offsigner_assignment_id`, `offsigner_assignment_rank_id`, `offsigner_assignment_position_id` | - | - |
| `onsigner_assignment_mapping` | FK lookup | `legacy_relief_id`, `onsigner_assignment_id`, `onsigner_assignment_rank_id`, `onsigner_assignment_position_id` | - | - |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `joining_place_id_mapping` | FK lookup | `joining_place_name`, `joining_place_id` | - | `smac_master_migration` |
| `onsigner_joining_place_mapping` | FK lookup | `reliever_seafarer_id`, `synergy_joining_place` | - | `synergy_seafarer` |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `position_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `seafarer_rank_position_mapping` | FK lookup | `legacy_seafarer_id`, `seafarer_rank_id`, `seafarer_position_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_revision_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `vessel_id_mapping`

- **Purpose**: Check for duplicate UUIDs in so
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `vessel_imo_mapping`

- **Output columns**: vessel_id, imo_number
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    TRIM(v.imo_number) AS imo_number
FROM dblink('smac_master_migration',
    'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
) AS v(id uuid, imo_number text)
WHERE TRIM(v.imo_number) != '';
```

### `relief_type_id_mapping`

- **Output columns**: relief_type_name_normalized, relief_type_name, relief_type_id, mapped_type
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE relief_type_id_mapping AS
SELECT
    UPPER(TRIM(rt.name)) AS relief_type_name_normalized,
    rt.name AS relief_type_name,
    rt.id AS relief_type_id,
    CASE
        WHEN UPPER(TRIM(rt.name)) LIKE '%ROTATION%' THEN 'ROTATION'
        WHEN UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL%' OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONALCREW%' OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL_CREW%' THEN 'ADDITIONAL CREW'
        WHEN UPPER(TRIM(rt.name)) LIKE '%REGULAR%' THEN 'REGULAR'
        ELSE NULL
    END AS mapped_type
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.relief_types'
) AS rt(id uuid, name text)
WHERE UPPER(TRIM(rt.name)) LIKE '%ROTATION%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONALCREW%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL CREW%'
   OR UPPER(TRIM(rt.name)) LIKE '%REGULAR%';
```

### `relief_state_id_mapping`

- **Output columns**: relief_state_code, relief_state_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE relief_state_id_mapping AS
SELECT
    rs.code AS relief_state_code,
    rs.id AS relief_state_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.relief_states'
) AS rs(id uuid, code text);
```

### `relief_seafarer_departures_lookup`

- **Purpose**: Create vessel lookup mapping by IMO number
- **Output columns**: relief_id, seafarer_id, status_normalized
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_seafarer_departures_lookup AS
SELECT DISTINCT ON (sd.relief_id)
    sd.relief_id::bigint AS relief_id,
    sd.seafarer_id::bigint AS seafarer_id,
    UPPER(TRIM(COALESCE(sd.status, ''))) AS status_normalized
FROM dblink('synergy_manning',
    'SELECT relief_id, seafarer_id, status, COALESCE(updated_at, created_at, NOW()) AS last_modified
     FROM public.seafarer_departures
     WHERE relief_id IS NOT NULL
       AND status IS NOT NULL
       AND UPPER(TRIM(status)) = ''SIGNED'''
) AS sd(relief_id bigint, seafarer_id bigint, status text, last_modified timestamp)
WHERE UPPER(TRIM(COALESCE(sd.status, ''))) = 'SIGNED'
ORDER BY sd.relief_id, sd.last_modified DESC;
```

### `offsigner_assignment_mapping`

- **Purpose**: Create relief_type lookup mapping from master data (crewing.relief_types)
- **Output columns**: legacy_relief_id, offsigner_assignment_id, offsigner_assignment_rank_id, offsigner_assignment_position_id

```sql
CREATE TEMP TABLE offsigner_assignment_mapping AS
SELECT
    rs.onboard_relief_id AS legacy_relief_id,
    rs.assignment_id AS offsigner_assignment_id,
    COALESCE(rs.contract_rank_id, rs.rank_id) as offsigner_assignment_rank_id,
    COALESCE(rs.contract_position_id, rs.position_id) as offsigner_assignment_position_id
FROM public.relief_summary rs
WHERE rs.onboard_relief_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid;
```

### `onsigner_assignment_mapping`

- **Output columns**: legacy_relief_id, onsigner_assignment_id, onsigner_assignment_rank_id, onsigner_assignment_position_id

```sql
CREATE TEMP TABLE onsigner_assignment_mapping AS
SELECT
    rs.planned_relief_id AS legacy_relief_id,
    rs.assignment_id AS onsigner_assignment_id,
    COALESCE(rs.contract_rank_id, rs.rank_id) as onsigner_assignment_rank_id,
    COALESCE(rs.contract_position_id, rs.position_id) as onsigner_assignment_position_id
FROM public.relief_summary rs
WHERE rs.planned_relief_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid;
```

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `joining_place_id_mapping`

- **Output columns**: joining_place_name, joining_place_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT
    TRIM(jp.name) as joining_place_name,
    jp.id as joining_place_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.joining_places'
) AS jp(id uuid, name text);
```

### `onsigner_joining_place_mapping`

- **Output columns**: reliever_seafarer_id, synergy_joining_place
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE onsigner_joining_place_mapping AS
SELECT
    s.id::bigint AS reliever_seafarer_id,
    TRIM(s.synergy_joining_place) AS synergy_joining_place
FROM dblink('synergy_seafarer',
    'SELECT id, synergy_joining_place FROM public.seafarers'
) AS s(id bigint, synergy_joining_place text);
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `position_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `seafarer_rank_position_mapping`

- **Output columns**: legacy_seafarer_id, seafarer_rank_id, seafarer_position_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_rank_position_mapping AS
SELECT
    tm.source_id::bigint AS legacy_seafarer_id,
    s.rank_id AS seafarer_rank_id,
    s.position_id AS seafarer_position_id
FROM migration.table_mappings tm
INNER JOIN public.seafarers s ON s.id = tm.target_id
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### `vessel_revision_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN (
    SELECT new_id AS vessel_id FROM vessel_id_mapping
    UNION
    SELECT vessel_id FROM vessel_imo_mapping
) AS all_vessels ON all_vessels.vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'reliefs'::VARCHAR(100), legacy_data.id::text, current_databas... |
| 2 | derived | - | offsigner_id | - | offsigner_map.new_id as offsigner_id | offsigner_map.new_id |
| 3 | derived | - | onsigner_id | - | onsigner_map.new_id as onsigner_id | onsigner_map.new_id |
| 4 | derived | - | offsigner_assignment_id | - | offsigner_assignment_map.offsigner_assignment_id AS offsigner_assignment_id | offsigner_assignment_map.offsigner_assignment_id |
| 5 | derived | - | onsigner_assignment_id | - | onsigner_assignment_map.onsigner_assignment_id AS onsigner_assignment_id | onsigner_assignment_map.onsigner_assignment_id |
| 6 | derived | - | vessel_id | - | COALESCE(vessel_map.new_id, vessel_imo_map.vessel_id) as vessel_id | COALESCE(vessel_map.new_id, vessel_imo_map.vessel_id) |
| 7 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 8 | derived | - | relief_type_id | - | COALESCE(relief_type_map.relief_type_id, '00000000-0000-0000-0000-000000000000'::uuid) as relief_type_id | COALESCE(relief_type_map.relief_type_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 9 | derived | - | relief_state_id | - | COALESCE(relief_state_map.relief_state_id, '00000000-0000-0000-0000-000000000000'::uuid) as relief_state_id | COALESCE(relief_state_map.relief_state_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 10 | reason | - | remarks | - | legacy_data.reason as remarks | legacy_data.reason |
| 11 | derived | - | workflow_status_id | - | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) as workflow_status_id | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 12 | derived | - | is_verified | - | true as is_verified | true |
| 13 | derived | - | verified_at | - | NULL as verified_at | NULL |
| 14 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 15 | derived | - | verification_notes | - | NULL as verification_notes | NULL |
| 16 | derived | - | status | - | 1 as status | 1 |
| 17 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 18 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 19 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 20 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 21 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 22 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 23 | onsigner_travel_plan | - | relief_date | - | CASE WHEN legacy_data.onsigner_travel_plan IS NOT NULL AND legacy_data.onsigner_travel_plan->>'planned_travel_date' IS NOT NULL THEN (legacy_data.onsigner_travel_plan->>'planned... | CASE WHEN legacy_data.onsigner_travel_plan IS NOT NULL AND legacy_data.onsigner_travel_plan->>'planned_travel_date' IS NOT NULL THEN (legacy_data.onsigner_travel_plan->>'planned... |
| 24 | - | - | joining_place_id | - | COALESCE(joining_place_map.joining_place_id, NULL::uuid) as joining_place_id | COALESCE(joining_place_map.joining_place_id, NULL::uuid) |
| 25 | derived | - | travel_date | - | NULL as travel_date | NULL |
| 26 | seafarer_rank_id | - | rank_id | - | COALESCE( rank_map.new_id, seafarer_rank_pos.seafarer_rank_id ) as rank_id | COALESCE( rank_map.new_id, seafarer_rank_pos.seafarer_rank_id ) |
| 27 | seafarer_position_id | - | position_id | - | COALESCE( position_map.new_id, seafarer_rank_pos.seafarer_position_id ) as position_id | COALESCE( position_map.new_id, seafarer_rank_pos.seafarer_position_id ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.relief_summary`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Vessel ID Mapping
**Purpose**: Check for duplicate UUIDs in so
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Vessel Imo ID Mapping
**Output columns**: `vessel_id, imo_number`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    TRIM(v.imo_number) AS imo_number
FROM dblink('smac_master_migration',
    'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
) AS v(id uuid, imo_number text)
WHERE TRIM(v.imo_number) != '';
```

### 4. Relief Type ID Mapping
**Output columns**: `relief_type_name_normalized, relief_type_name, relief_type_id, mapped_type`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE relief_type_id_mapping AS
SELECT
    UPPER(TRIM(rt.name)) AS relief_type_name_normalized,
    rt.name AS relief_type_name,
    rt.id AS relief_type_id,
    CASE
        WHEN UPPER(TRIM(rt.name)) LIKE '%ROTATION%' THEN 'ROTATION'
        WHEN UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL%' OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONALCREW%' OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL_CREW%' THEN 'ADDITIONAL CREW'
        WHEN UPPER(TRIM(rt.name)) LIKE '%REGULAR%' THEN 'REGULAR'
        ELSE NULL
    END AS mapped_type
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.relief_types'
) AS rt(id uuid, name text)
WHERE UPPER(TRIM(rt.name)) LIKE '%ROTATION%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONALCREW%'
   OR UPPER(TRIM(rt.name)) LIKE '%ADDITIONAL CREW%'
   OR UPPER(TRIM(rt.name)) LIKE '%REGULAR%';
```

### 5. Relief State ID Mapping
**Output columns**: `relief_state_code, relief_state_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE relief_state_id_mapping AS
SELECT
    rs.code AS relief_state_code,
    rs.id AS relief_state_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.relief_states'
) AS rs(id uuid, code text);
```

### 6. Relief Seafarer Departures ID Mapping
**Purpose**: Create vessel lookup mapping by IMO number
**Output columns**: `relief_id, seafarer_id, status_normalized`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_seafarer_departures_lookup AS
SELECT DISTINCT ON (sd.relief_id)
    sd.relief_id::bigint AS relief_id,
    sd.seafarer_id::bigint AS seafarer_id,
    UPPER(TRIM(COALESCE(sd.status, ''))) AS status_normalized
FROM dblink('synergy_manning',
    'SELECT relief_id, seafarer_id, status, COALESCE(updated_at, created_at, NOW()) AS last_modified
     FROM public.seafarer_departures
     WHERE relief_id IS NOT NULL
       AND status IS NOT NULL
       AND UPPER(TRIM(status)) = ''SIGNED'''
) AS sd(relief_id bigint, seafarer_id bigint, status text, last_modified timestamp)
WHERE UPPER(TRIM(COALESCE(sd.status, ''))) = 'SIGNED'
ORDER BY sd.relief_id, sd.last_modified DESC;
```

### 7. Offsigner Assignment ID Mapping
**Purpose**: Create relief_type lookup mapping from master data (crewing.relief_types)
**Output columns**: `legacy_relief_id, offsigner_assignment_id, offsigner_assignment_rank_id, offsigner_assignment_position_id`

```sql
CREATE TEMP TABLE offsigner_assignment_mapping AS
SELECT
    rs.onboard_relief_id AS legacy_relief_id,
    rs.assignment_id AS offsigner_assignment_id,
    COALESCE(rs.contract_rank_id, rs.rank_id) as offsigner_assignment_rank_id,
    COALESCE(rs.contract_position_id, rs.position_id) as offsigner_assignment_position_id
FROM public.relief_summary rs
WHERE rs.onboard_relief_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid;
```

### 8. Onsigner Assignment ID Mapping
**Output columns**: `legacy_relief_id, onsigner_assignment_id, onsigner_assignment_rank_id, onsigner_assignment_position_id`

```sql
CREATE TEMP TABLE onsigner_assignment_mapping AS
SELECT
    rs.planned_relief_id AS legacy_relief_id,
    rs.assignment_id AS onsigner_assignment_id,
    COALESCE(rs.contract_rank_id, rs.rank_id) as onsigner_assignment_rank_id,
    COALESCE(rs.contract_position_id, rs.position_id) as onsigner_assignment_position_id
FROM public.relief_summary rs
WHERE rs.planned_relief_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid;
```

### 9. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 10. Joining Place ID Mapping
**Output columns**: `joining_place_name, joining_place_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT
    TRIM(jp.name) as joining_place_name,
    jp.id as joining_place_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.joining_places'
) AS jp(id uuid, name text);
```

### 11. Onsigner Joining Place ID Mapping
**Output columns**: `reliever_seafarer_id, synergy_joining_place`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE onsigner_joining_place_mapping AS
SELECT
    s.id::bigint AS reliever_seafarer_id,
    TRIM(s.synergy_joining_place) AS synergy_joining_place
FROM dblink('synergy_seafarer',
    'SELECT id, synergy_joining_place FROM public.seafarers'
) AS s(id bigint, synergy_joining_place text);
```

### 12. Rank ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 13. Position ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 14. Seafarer Rank Position ID Mapping
**Output columns**: `legacy_seafarer_id, seafarer_rank_id, seafarer_position_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_rank_position_mapping AS
SELECT
    tm.source_id::bigint AS legacy_seafarer_id,
    s.rank_id AS seafarer_rank_id,
    s.position_id AS seafarer_position_id
FROM migration.table_mappings tm
INNER JOIN public.seafarers s ON s.id = tm.target_id
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### 15. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN (
    SELECT new_id AS vessel_id FROM vessel_id_mapping
    UNION
    SELECT vessel_id FROM vessel_imo_mapping
) AS all_vessels ON all_vessels.vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/crewing/seafarer_reliefs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_reliefs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_reliefs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
