# Table Mapping: seafarer_checklists → seafarer_departure_checklist_items

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_checklists
- **New Database**: smac_master_migration
- **New Schema**: shore
- **New Table**: seafarer_departure_checklist_items
- **Source Script**: `04-migration-scripts/crewing/seafarer_departure_checklist_items_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_checklists`
- **New Path**: `smac_master_migration.shore.seafarer_departure_checklist_items`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departure Checklist Items (`seafarer_departures,seafarer_checklists` → `seafarer_departure_checklist_items`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_departure_checklist_items from seafarer_departures and seafarer_checklists. Joins on seafarer_departures.id = seafarer_checklists.seafarer_departure_id. Maps departure_checklist_id to checklist_item_id via departure_checklist master table. Converts deviation_reviewers JSONB to UUID array. Sets deviation_flag based on deviation_note presence.

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE shore.seafarer_departure_checklist_items` before insert (full table reload).
- Orchestration dependencies: `seafarer_departures`, `departure_checklist`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_departure_id_mapping` | Check if any mappings already exist for the given source and | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `checklist_item_id_mapping` | FK lookup | `legacy_departure_checklist_id`, `checklist_item_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |

### `seafarer_departure_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_departures

```sql
CREATE TEMP TABLE seafarer_departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `checklist_item_id_mapping`

- **Output columns**: legacy_departure_checklist_id, checklist_item_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE checklist_item_id_mapping AS
SELECT
    source_id::bigint AS legacy_departure_checklist_id,
    target_id AS checklist_item_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''departure_checklist'' /* AND target_db = ''smac_master_migration'' */ AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_checklists'::VARCHAR(100), checklist_data.id::text, current_database()::text::VAR... |
| 2 | derived | - | seafarer_departure_id | - | COALESCE(departure_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_departure_id | COALESCE(departure_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | checklist_item_id | - | COALESCE(checklist_map.checklist_item_id, '00000000-0000-0000-0000-000000000000'::uuid) as checklist_item_id | COALESCE(checklist_map.checklist_item_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | is_completed | - | COALESCE(checklist_data.is_completed, false) as is_completed | COALESCE(checklist_data.is_completed, false) |
| 5 | derived | - | completed_at | - | CASE WHEN checklist_data.is_completed = true THEN checklist_data.updated_at ELSE NULL END as completed_at | CASE WHEN checklist_data.is_completed = true THEN checklist_data.updated_at ELSE NULL END |
| 6 | derived | - | completed_by_id | - | CASE WHEN checklist_data.is_completed = true AND checklist_data.updated_by_id IS NOT NULL AND TRIM(checklist_data.updated_by_id) <> '' AND checklist_data.updated_by_id ~ '^[0-9a... | CASE WHEN checklist_data.is_completed = true AND checklist_data.updated_by_id IS NOT NULL AND TRIM(checklist_data.updated_by_id) <> '' AND checklist_data.updated_by_id ~ '^[0-9a... |
| 7 | - | - | check_point | - | CASE WHEN checklist_data.availability IS NULL THEN NULL::integer WHEN checklist_data.availability = 0 THEN 2 WHEN checklist_data.availability = 1 THEN 1 WHEN checklist_data.avai... | CASE WHEN checklist_data.availability IS NULL THEN NULL::integer WHEN checklist_data.availability = 0 THEN 2 WHEN checklist_data.availability = 1 THEN 1 WHEN checklist_data.avai... |
| 8 | derived | - | deviation_note | - | checklist_data.deviation_note as deviation_note | checklist_data.deviation_note |
| 9 | - | - | deviation_reviewers | - | CASE WHEN checklist_data.deviation_reviewers IS NOT NULL AND jsonb_typeof(checklist_data.deviation_reviewers) = 'array' THEN ARRAY( SELECT DISTINCT user_map.user_id FROM jsonb_a... | CASE WHEN checklist_data.deviation_reviewers IS NOT NULL AND jsonb_typeof(checklist_data.deviation_reviewers) = 'array' THEN ARRAY( SELECT DISTINCT user_map.user_id FROM jsonb_a... |
| 10 | derived | - | deviation_status | - | COALESCE(checklist_data.deviation_status, 0) as deviation_status | COALESCE(checklist_data.deviation_status, 0) |
| 11 | derived | - | deviation_flag | - | false as deviation_flag | false |
| 12 | derived | - | workflow_status_id | - | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS workflow_status_id | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 13 | derived | - | is_verified | - | false as is_verified | false |
| 14 | - | - | verified_at | - | NULL | NULL::timestamp |
| 15 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 16 | - | - | verification_notes | - | NULL | NULL::text |
| 17 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 18 | derived | - | created_at | - | COALESCE(checklist_data.created_at, NOW()) as created_at | COALESCE(checklist_data.created_at, NOW()) |
| 19 | derived | - | updated_at | - | COALESCE(checklist_data.updated_at, NOW()) as updated_at | COALESCE(checklist_data.updated_at, NOW()) |
| 20 | derived | - | deleted_at | - | checklist_data.deleted_at as deleted_at | checklist_data.deleted_at |
| 21 | - | - | archived_at | - | NULL | NULL::timestamp |
| 22 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( checklist_data.created_by_id::varchar, NULL::varchar, checklist_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::var... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Departure ID Mapping
**Purpose**: Check if any mappings already exist for the given source and
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_departures'`

```sql
CREATE TEMP TABLE seafarer_departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Checklist Item ID Mapping
**Output columns**: `legacy_departure_checklist_id, checklist_item_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE checklist_item_id_mapping AS
SELECT
    source_id::bigint AS legacy_departure_checklist_id,
    target_id AS checklist_item_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''departure_checklist'' /* AND target_db = ''smac_master_migration'' */ AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_departure_checklist_items_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departure_checklist_items_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departure_checklist_items_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
