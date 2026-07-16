# Table Mapping: supernumerary_complements → supernumerary_assignments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: supernumerary_complements
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: supernumerary_assignments
- **Source Script**: `04-migration-scripts/crewing/supernumerary_assignments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.supernumerary_complements`
- **New Path**: `smac_crewing_migration.public.supernumerary_assignments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Supernumerary Assignments (`supernumerary_complements` → `supernumerary_assignments`)

## Migration Notes

- Migrates supernumerary_complements to supernumerary_assignments. Preserves UUID as id. Maps vessel_id, nationality_id, family_details_id, and ports via migration.table_mappings. Extracts port IDs from JSONB fields. Maps current_relief_id to seafarer_assignment_id. Gets active vessel_revision_id from vessel_revisions table.

## Special Considerations

- Script performs `TRUNCATE TABLE public.supernumerary_assignments` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`, `ranks`, `positions`, `nationalities`, `ports`, `workflow_status`, `time_zones`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 8

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |
| `family_details_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `assignment_id_mapping` | FK lookup | `legacy_relief_id`, `assignment_id` | `migration.table_mappings` (see SQL) | - |
| `nationality_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_id_mapping` | Assignme | `workflow_status_id` | - | `smac_master_migration` |
| `time_zone_id_mapping` | FK lookup | `time_zone_id` | - | `smac_master_migration` |

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### `family_details_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_family_members

```sql
CREATE TEMP TABLE family_details_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_family_members'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `assignment_id_mapping`

- **Output columns**: legacy_relief_id, assignment_id
- **migration.table_mappings**: target_table=seafarer_vessel_assignments

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `nationality_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `workflow_status_id_mapping`

- **Purpose**: Assignme
- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `time_zone_id_mapping`

- **Output columns**: time_zone_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE time_zone_id_mapping AS
SELECT id AS time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE code = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'supernumerary_complements'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | vessel_id | - | vessel_map.new_id AS vessel_id | vessel_map.new_id |
| 3 | derived | - | vessel_revision_id | - | COALESCE( vessel_revision_map.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS vessel_revision_id | COALESCE( vessel_revision_map.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | seafarer_id | - | seafarer_id | - | legacy_data.seafarer_id AS seafarer_id | legacy_data.seafarer_id |
| 5 | derived | - | family_details_id | - | family_map.new_id AS family_details_id | family_map.new_id |
| 6 | - | - | family_details_info | - | NULL | NULL::text |
| 7 | derived | - | seafarer_assignment_id | - | assignment_map.assignment_id AS seafarer_assignment_id | assignment_map.assignment_id |
| 8 | supernumerary_rank_id | - | rank_id | - | legacy_data.supernumerary_rank_id AS rank_id | legacy_data.supernumerary_rank_id |
| 9 | supernumerary_position | - | position_id | - | legacy_data.supernumerary_position AS position_id | legacy_data.supernumerary_position |
| 10 | derived | - | nationality_id | - | nationality_map.new_id AS nationality_id | nationality_map.new_id |
| 11 | complement_code | - | supernumerary_code | - | TRIM(legacy_data.complement_code) AS supernumerary_code | TRIM(legacy_data.complement_code) |
| 12 | first_name | - | first_name | - | TRIM(legacy_data.first_name) AS first_name | TRIM(legacy_data.first_name) |
| 13 | last_name | - | last_name | - | TRIM(legacy_data.last_name) AS last_name | TRIM(legacy_data.last_name) |
| 14 | date_of_birth | - | dob | - | legacy_data.date_of_birth::timestamp AS dob | legacy_data.date_of_birth::timestamp |
| 15 | status | - | on_board_status | - | COALESCE(TRIM(legacy_data.status), 'Active') AS on_board_status | COALESCE(TRIM(legacy_data.status), 'Active') |
| 16 | actual_sign_on_date | - | sign_on_timestamp_utc | - | CAST(legacy_data.actual_sign_on_date AS timestamp) AS sign_on_timestamp_utc | CAST(legacy_data.actual_sign_on_date AS timestamp) |
| 17 | actual_sign_on_date | - | sign_on_timestamp_local | - | CAST(legacy_data.actual_sign_on_date AS timestamp) AS sign_on_timestamp_local | CAST(legacy_data.actual_sign_on_date AS timestamp) |
| 18 | actual_sign_on_port | - | sign_on_port_id | - | CASE WHEN legacy_data.actual_sign_on_port IS NOT NULL AND legacy_data.actual_sign_on_port->>'id' ~ '^[0-9]+$' THEN port_map.new_id ELSE '00000000-0000-0000-0000-000000000000'::u... | CASE WHEN legacy_data.actual_sign_on_port IS NOT NULL AND legacy_data.actual_sign_on_port->>'id' ~ '^[0-9]+$' THEN port_map.new_id ELSE '00000000-0000-0000-0000-000000000000'::u... |
| 19 | derived | - | sign_on_time_zone_id | - | COALESCE( time_zone_map.time_zone_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS sign_on_time_zone_id | COALESCE( time_zone_map.time_zone_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 20 | sign_on_initiated_info | - | sign_on_remarks | - | CASE WHEN legacy_data.sign_on_initiated_info IS NOT NULL THEN legacy_data.sign_on_initiated_info::text ELSE NULL END AS sign_on_remarks | CASE WHEN legacy_data.sign_on_initiated_info IS NOT NULL THEN legacy_data.sign_on_initiated_info::text ELSE NULL END |
| 21 | sign_on_confirmed_by | - | sign_on_confirmed_by | - | CASE WHEN legacy_data.sign_on_confirmed_by IS NOT NULL AND legacy_data.sign_on_confirmed_by ? 'id' THEN (legacy_data.sign_on_confirmed_by->>'id')::uuid ELSE NULL END AS sign_on_... | CASE WHEN legacy_data.sign_on_confirmed_by IS NOT NULL AND legacy_data.sign_on_confirmed_by ? 'id' THEN (legacy_data.sign_on_confirmed_by->>'id')::uuid ELSE NULL END |
| 22 | sign_on_confirmed_by | - | sign_on_confirmed_on | - | CASE WHEN legacy_data.sign_on_confirmed_by IS NOT NULL AND legacy_data.sign_on_confirmed_by ? 'id' THEN NOW() ELSE NULL END AS sign_on_confirmed_on | CASE WHEN legacy_data.sign_on_confirmed_by IS NOT NULL AND legacy_data.sign_on_confirmed_by ? 'id' THEN NOW() ELSE NULL END |
| 23 | actual_sign_off_date | - | has_sign_off_info | - | CASE WHEN legacy_data.actual_sign_off_date IS NOT NULL THEN true ELSE false END AS has_sign_off_info | CASE WHEN legacy_data.actual_sign_off_date IS NOT NULL THEN true ELSE false END |
| 24 | planned_sign_off_date_info | - | expected_sign_off_info | - | CASE WHEN legacy_data.planned_sign_off_date_info IS NOT NULL THEN legacy_data.planned_sign_off_date_info::text ELSE NULL END AS expected_sign_off_info | CASE WHEN legacy_data.planned_sign_off_date_info IS NOT NULL THEN legacy_data.planned_sign_off_date_info::text ELSE NULL END |
| 25 | actual_sign_off_date | - | sign_off_timestamp_utc | - | CAST(legacy_data.actual_sign_off_date AS timestamp) AS sign_off_timestamp_utc | CAST(legacy_data.actual_sign_off_date AS timestamp) |
| 26 | actual_sign_off_date | - | sign_off_timestamp_local | - | CAST(legacy_data.actual_sign_off_date AS timestamp) AS sign_off_timestamp_local | CAST(legacy_data.actual_sign_off_date AS timestamp) |
| 27 | actual_sign_off_port | - | sign_off_port_id | - | CASE WHEN legacy_data.actual_sign_off_port IS NOT NULL AND legacy_data.actual_sign_off_port->>'id' ~ '^[0-9]+$' THEN port_map_sign_off.new_id ELSE NULL END AS sign_off_port_id | CASE WHEN legacy_data.actual_sign_off_port IS NOT NULL AND legacy_data.actual_sign_off_port->>'id' ~ '^[0-9]+$' THEN port_map_sign_off.new_id ELSE NULL END |
| 28 | derived | - | sign_off_time_zone_id | - | time_zone_map.time_zone_id AS sign_off_time_zone_id | time_zone_map.time_zone_id |
| 29 | - | - | sign_off_remarks | - | NULL | NULL::text |
| 30 | sign_off_confirmed_by | - | sign_off_confirmed_by | - | CASE WHEN legacy_data.sign_off_confirmed_by IS NOT NULL AND legacy_data.sign_off_confirmed_by ? 'id' THEN (legacy_data.sign_off_confirmed_by->>'id')::uuid ELSE NULL END AS sign_... | CASE WHEN legacy_data.sign_off_confirmed_by IS NOT NULL AND legacy_data.sign_off_confirmed_by ? 'id' THEN (legacy_data.sign_off_confirmed_by->>'id')::uuid ELSE NULL END |
| 31 | sign_off_confirmed_by | - | sign_off_confirmed_on | - | CASE WHEN legacy_data.sign_off_confirmed_by IS NOT NULL AND legacy_data.sign_off_confirmed_by ? 'id' THEN NOW() ELSE NULL END AS sign_off_confirmed_on | CASE WHEN legacy_data.sign_off_confirmed_by IS NOT NULL AND legacy_data.sign_off_confirmed_by ? 'id' THEN NOW() ELSE NULL END |
| 32 | actual_duration_in_days | - | tenure | - | legacy_data.actual_duration_in_days::text AS tenure | legacy_data.actual_duration_in_days::text |
| 33 | derived | - | workflow_status_id | - | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS workflow_status_id | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 34 | derived | - | is_verified | - | false AS is_verified | false |
| 35 | - | - | verified_at | - | NULL | NULL::timestamp |
| 36 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 37 | - | - | verification_notes | - | NULL | NULL::text |
| 38 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 39 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 40 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 41 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 42 | - | - | archived_at | - | NULL | NULL::timestamp |
| 43 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 44 | audit_info | - | audit_info | - | legacy_data.audit_info AS audit_info | legacy_data.audit_info |
| 45 | - | - | remarks | - | NULL | NULL::text |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 2. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 3. Family Details ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_family_members'`

```sql
CREATE TEMP TABLE family_details_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_family_members'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 4. Assignment ID Mapping
**Output columns**: `legacy_relief_id, assignment_id`
**migration.table_mappings**: `target_table='seafarer_vessel_assignments'`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 5. Nationality ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 6. Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 7. Workflow Status ID Mapping
**Purpose**: Assignme
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 8. Time Zone ID Mapping
**Output columns**: `time_zone_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE time_zone_id_mapping AS
SELECT id AS time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE code = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/supernumerary_assignments_migration.sql`

## Validation

- Run `05-validation/crewing/supernumerary_assignments_validation.sql` if available
- Run `06-rollback/crewing/supernumerary_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
