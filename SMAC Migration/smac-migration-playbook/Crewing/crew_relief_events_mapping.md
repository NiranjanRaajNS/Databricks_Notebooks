# Table Mapping: crew_relief_event → crew_relief_events

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: crew_relief_event
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crew_relief_events
- **Source Script**: `04-migration-scripts/crewing/crew_relief_events_migration.sql`

- **Legacy Path**: `synergy_manning.public.crew_relief_event`
- **New Path**: `smac_crewing_migration.public.crew_relief_events`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Crew Relief Events (`crew_relief_event` → `crew_relief_events`)

## Migration Notes

- Migrates crew_relief_event to crew_relief_events preserving UUID id. Extracts event_port_id, port_call_id, and port_agent_id from JSONB fields. Maps vessel_id from bigint to UUID.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crew_relief_events` before insert (full table reload).
- Orchestration dependencies: `vessels`, `ports`, `agents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `port_agent_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `vessel_id_mapping`

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

### `port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `port_agent_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_agent_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''agents'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'crew_relief_event'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | vessel_id | - | vessel_map.new_id AS vessel_id | vessel_map.new_id |
| 3 | event_code | - | event_code | - | TRIM(legacy_data.event_code) AS event_code | TRIM(legacy_data.event_code) |
| 4 | event_name | - | event_name | - | TRIM(legacy_data.event_name) AS event_name | TRIM(legacy_data.event_name) |
| 5 | derived | - | event_type | - | 'Scheduled'::varchar(50) AS event_type | 'Scheduled'::varchar(50) |
| 6 | status | - | event_status | - | CASE WHEN TRIM(legacy_data.status) = 'Closed' THEN 'Completed' ELSE 'Planned' END::varchar(50) AS event_status | CASE WHEN TRIM(legacy_data.status) = 'Closed' THEN 'Completed' ELSE 'Planned' END::varchar(50) |
| 7 | start_date | - | start_date | - | CAST(legacy_data.start_date AS timestamp) AS start_date | CAST(legacy_data.start_date AS timestamp) |
| 8 | end_date | - | end_date | - | CAST(legacy_data.end_date AS timestamp) AS end_date | CAST(legacy_data.end_date AS timestamp) |
| 9 | eta | - | eta | - | legacy_data.eta AS eta | legacy_data.eta |
| 10 | eta_source | - | eta_source | - | TRIM(legacy_data.eta_source) AS eta_source | TRIM(legacy_data.eta_source) |
| 11 | is_eta_mismatch | - | is_eta_mismatch | - | legacy_data.is_eta_mismatch AS is_eta_mismatch | legacy_data.is_eta_mismatch |
| 12 | derived | - | event_port_id | - | port_map.new_id AS event_port_id | port_map.new_id |
| 13 | derived | - | port_call_id | - | port_call_map.new_id AS port_call_id | port_call_map.new_id |
| 14 | nearest_airport | - | nearest_airport | - | TRIM(legacy_data.nearest_airport) AS nearest_airport | TRIM(legacy_data.nearest_airport) |
| 15 | derived | - | port_agent_id | - | port_agent_map.new_id AS port_agent_id | port_agent_map.new_id |
| 16 | remarks | - | remarks | - | TRIM(legacy_data.remarks) AS remarks | TRIM(legacy_data.remarks) |
| 17 | closure_remarks | - | closure_remarks | - | TRIM(legacy_data.closure_remarks) AS closure_remarks | TRIM(legacy_data.closure_remarks) |
| 18 | is_active | - | status | - | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END::varchar(50) AS status | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END::varchar(50) |
| 19 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 20 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 21 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 22 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 23 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

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
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 2. Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Port Agent ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_agent_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''agents'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/crewing/crew_relief_events_migration.sql`

## Validation

- Run `05-validation/crewing/crew_relief_events_validation.sql` if available
- Run `06-rollback/crewing/crew_relief_events_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
