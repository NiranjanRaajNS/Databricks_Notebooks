# Table Mapping: crew_relief_event → crew_event_assignments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: crew_relief_event
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crew_event_assignments
- **Source Script**: `04-migration-scripts/crewing/crew_event_assignments_migration.sql`

- **Legacy Path**: `synergy_manning.public.crew_relief_event`
- **New Path**: `smac_crewing_migration.public.crew_event_assignments`

## Business Key

- **Composite Key**: (`event_id`, `assignment_id`)
- **Source (orchestration)**: Relief event crew mapping (Manning) (`relief_event_crew_mapping` → `crew_event_assignments`)

## Migration Notes

- One crew_relief_event can have multiple assignments (one per relief)
- Migrates synergy_manning.public.relief_event_crew_mapping into crew_event_assignments. travel_request_id: travel_ticket_requests INNER JOIN travel_tickets (relief_id + seafarer_id, tickets.deleted_at IS NULL), keyed by relief+seafarer to match crew mapping rows; then table_mappings to crewing_travel_requests. Requires relief_summary. Deletes orphan synergy_seafarer mappings.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crew_event_assignments` before insert (full table reload).
- Orchestration dependencies: `crew_relief_events`, `seafarer_vessel_assignments`, `crewing_travel_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `event_id_mapping` | FK lookup | `legacy_event_id`, `event_id` | `migration.table_mappings` (see SQL) | - |
| `assignment_to_relief_uuid_mapping` | FK lookup | `assignment_id`, `seafarer_relief_id` | - | - |
| `relief_uuid_to_id_mapping` | FK lookup | `relief_uuid`, `legacy_relief_id` | - | `synergy_manning` |
| `relief_id_to_travel_request_mapping` | FK lookup | `legacy_relief_id`, `legacy_travel_request_id` | - | `synergy_manning` |
| `travel_request_id_mapping` | Assignment ID mapping: Use relief_summary table (same logic as crewing_travel_requests) | `legacy_travel_request_id`, `travel_request_id` | `migration.table_mappings` (see SQL) | - |

### `event_id_mapping`

- **Output columns**: legacy_event_id, event_id
- **migration.table_mappings**: target_table=crew_relief_events

```sql
CREATE TEMP TABLE event_id_mapping AS
SELECT
    source_id::text AS legacy_event_id,
    target_id AS event_id
FROM migration.table_mappings
WHERE target_table = 'crew_relief_events'
  AND target_db = current_database();
```

### `assignment_to_relief_uuid_mapping`

- **Output columns**: assignment_id, seafarer_relief_id

```sql
CREATE TEMP TABLE assignment_to_relief_uuid_mapping AS
SELECT
    id AS assignment_id,
    seafarer_relief_id
FROM public.seafarer_vessel_assignments
WHERE seafarer_relief_id IS NOT NULL;
```

### `relief_uuid_to_id_mapping`

- **Output columns**: relief_uuid, legacy_relief_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_uuid_to_id_mapping AS
SELECT
    uuid AS relief_uuid,
    id AS legacy_relief_id
FROM dblink('synergy_manning',
    'SELECT uuid, id FROM public.reliefs WHERE uuid IS NOT NULL'
) AS r(uuid uuid, id bigint);
```

### `relief_id_to_travel_request_mapping`

- **Output columns**: legacy_relief_id, legacy_travel_request_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_id_to_travel_request_mapping AS
SELECT DISTINCT ON (ttr.relief_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.id AS legacy_travel_request_id
FROM dblink('synergy_manning',
    'SELECT id, relief_id, created_at FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND deleted_at IS NULL'
) AS ttr(id bigint, relief_id bigint, created_at timestamp)
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.created_at DESC NULLS LAST, ttr.id DESC NULLS LAST;
```

### `travel_request_id_mapping`

- **Purpose**: Assignment ID mapping: Use relief_summary table (same logic as crewing_travel_requests)
- **Output columns**: legacy_travel_request_id, travel_request_id
- **migration.table_mappings**: target_table=crewing_travel_requests

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT
    source_id::bigint AS legacy_travel_request_id,
    target_id::uuid AS travel_request_id
FROM migration.table_mappings
WHERE target_table = 'crewing_travel_requests'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON ((cre_data.event_id::text || '|' || r_data.relief_id::text)) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'crew_relief_event... |
| 2 | derived | - | event_id | - | event_map.event_id | event_map.event_id |
| 3 | derived | - | assignment_id | - | COALESCE( relief_summary.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS assignment_id | COALESCE( relief_summary.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | derived | - | travel_request_id | - | travel_request_map.travel_request_id::uuid AS travel_request_id | travel_request_map.travel_request_id::uuid |
| 5 | derived | - | event_activity | - | CASE WHEN cre_data.sign_on_info IS NOT NULL AND cre_data.sign_on_info::text ILIKE '%sign_on%' THEN 'sign_on'::varchar(50) WHEN cre_data.sign_on_info IS NOT NULL AND cre_data.sig... | CASE WHEN cre_data.sign_on_info IS NOT NULL AND cre_data.sign_on_info::text ILIKE '%sign_on%' THEN 'sign_on'::varchar(50) WHEN cre_data.sign_on_info IS NOT NULL AND cre_data.sig... |
| 6 | derived | - | state | - | 'Open'::varchar(50) AS state | 'Open'::varchar(50) |
| 7 | derived | - | status | - | TRIM(cre_data.status) AS status | TRIM(cre_data.status) |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | created_at | - | COALESCE(cre_data.created_at, NOW()) AS created_at | COALESCE(cre_data.created_at, NOW()) |
| 10 | derived | - | updated_at | - | cre_data.updated_at AS updated_at | cre_data.updated_at |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Event ID Mapping
**Output columns**: `legacy_event_id, event_id`
**migration.table_mappings**: `target_table='crew_relief_events'`

```sql
CREATE TEMP TABLE event_id_mapping AS
SELECT
    source_id::text AS legacy_event_id,
    target_id AS event_id
FROM migration.table_mappings
WHERE target_table = 'crew_relief_events'
  AND target_db = current_database();
```

### 2. Assignment To Relief Uuid ID Mapping
**Output columns**: `assignment_id, seafarer_relief_id`

```sql
CREATE TEMP TABLE assignment_to_relief_uuid_mapping AS
SELECT
    id AS assignment_id,
    seafarer_relief_id
FROM public.seafarer_vessel_assignments
WHERE seafarer_relief_id IS NOT NULL;
```

### 3. Relief Uuid To ID Mapping
**Output columns**: `relief_uuid, legacy_relief_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_uuid_to_id_mapping AS
SELECT
    uuid AS relief_uuid,
    id AS legacy_relief_id
FROM dblink('synergy_manning',
    'SELECT uuid, id FROM public.reliefs WHERE uuid IS NOT NULL'
) AS r(uuid uuid, id bigint);
```

### 4. Relief Id To Travel Request ID Mapping
**Output columns**: `legacy_relief_id, legacy_travel_request_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_id_to_travel_request_mapping AS
SELECT DISTINCT ON (ttr.relief_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.id AS legacy_travel_request_id
FROM dblink('synergy_manning',
    'SELECT id, relief_id, created_at FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND deleted_at IS NULL'
) AS ttr(id bigint, relief_id bigint, created_at timestamp)
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.created_at DESC NULLS LAST, ttr.id DESC NULLS LAST;
```

### 5. Travel Request ID Mapping
**Purpose**: Assignment ID mapping: Use relief_summary table (same logic as crewing_travel_requests)
**Output columns**: `legacy_travel_request_id, travel_request_id`
**migration.table_mappings**: `target_table='crewing_travel_requests'`

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT
    source_id::bigint AS legacy_travel_request_id,
    target_id::uuid AS travel_request_id
FROM migration.table_mappings
WHERE target_table = 'crewing_travel_requests'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/crew_event_assignments_migration.sql`

## Validation

- Run `05-validation/crewing/crew_event_assignments_validation.sql` if available
- Run `06-rollback/crewing/crew_event_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
