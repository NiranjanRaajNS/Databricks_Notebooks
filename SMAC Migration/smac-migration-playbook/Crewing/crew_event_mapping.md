# Table Mapping: crew_event_mapping → crew_event_mapping

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: crew_event_mapping
- **Source Script**: `04-migration-scripts/crewing/crew_event_mapping_migration.sql`


## Business Key

- **Composite Key**: (`event_id`, `assignment_id`)
- **Source (orchestration)**: Relief event crew mapping (Manning) (`relief_event_crew_mapping` → `crew_event_assignments`)

## Migration Notes

- Migrates synergy_manning.public.relief_event_crew_mapping into crew_event_assignments. travel_request_id: travel_ticket_requests INNER JOIN travel_tickets (relief_id + seafarer_id, tickets.deleted_at IS NULL), keyed by relief+seafarer to match crew mapping rows; then table_mappings to crewing_travel_requests. Requires relief_summary. Deletes orphan synergy_seafarer mappings.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crew_event_assignments` before insert (full table reload).
- Orchestration dependencies: `crew_relief_events`, `seafarer_vessel_assignments`, `crewing_travel_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `crew_event_mapping` | Prerequisites: dblink synergy_manning; public.relief_event_crew_mapping on that database; | `m.id`, `m.relief_id`, `m.event_id`, `m.seafarer_id`, `m.is_on_signer`, `m.created_at`, `m.updated_at`, `m.audit_info` | - | `synergy_manning` |
| `event_id_mapping` | FK lookup | `legacy_event_id`, `event_id` | `migration.table_mappings` (see SQL) | - |
| `travel_request_id_mapping` | FK lookup | `legacy_travel_request_id`, `travel_request_id` | `migration.table_mappings` (see SQL) | - |
| `relief_id_to_travel_request_mapping` | FK lookup | `legacy_relief_id`, `legacy_seafarer_id`, `legacy_travel_request_id` | - | `synergy_manning` |

### `crew_event_mapping`

- **Purpose**: Prerequisites: dblink synergy_manning; public.relief_event_crew_mapping on that database;
- **Output columns**: m.id, m.relief_id, m.event_id, m.seafarer_id, m.is_on_signer, m.created_at, m.updated_at, m.audit_info
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE crew_event_mapping AS
SELECT
    m.id,
    m.relief_id,
    m.event_id,
    m.seafarer_id,
    m.is_on_signer,
    m.created_at,
    m.updated_at,
    m.audit_info
FROM dblink(
    'synergy_manning',
    $SAC$
    SELECT
        id,
        relief_id,
        event_id,
        seafarer_id,
        is_on_signer,
        created_at,
        updated_at,
        audit_info
    FROM public.relief_event_crew_mapping
    WHERE event_id IS NOT NULL
      AND relief_id IS NOT NULL
      AND seafarer_id IS NOT NULL
    $SAC$
) AS m(
    id uuid,
    relief_id bigint,
    event_id uuid,
    seafarer_id bigint,
    is_on_signer boolean,
    created_at timestamp,
    updated_at timestamp,
    audit_info jsonb
);
```

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

### `travel_request_id_mapping`

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

### `relief_id_to_travel_request_mapping`

- **Output columns**: legacy_relief_id, legacy_seafarer_id, legacy_travel_request_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_id_to_travel_request_mapping AS
SELECT DISTINCT ON (ttr.relief_id, ttr.seafarer_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.seafarer_id AS legacy_seafarer_id,
    ttr.id AS legacy_travel_request_id
FROM dblink(
    'synergy_manning',
    $TRAV$
    SELECT ttr.id, ttr.relief_id, ttr.seafarer_id, ttr.created_at
    FROM public.travel_ticket_requests ttr
    INNER JOIN public.travel_tickets tt
        ON tt.relief_id = ttr.relief_id
        AND tt.seafarer_id = ttr.seafarer_id
        AND tt.deleted_at IS NULL
    WHERE ttr.relief_id IS NOT NULL
      AND ttr.seafarer_id IS NOT NULL
      AND ttr.deleted_at IS NULL
    $TRAV$
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint, created_at timestamp)
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.seafarer_id, ttr.created_at DESC NULLS LAST, ttr.id DESC NULLS LAST;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (m.id) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'relief_event_crew_mapping'::VARCHAR(100), m.id::text, current_database(... |
| 2 | derived | - | event_id | - | em.event_id | em.event_id |
| 3 | assignment_id | - | assignment_id | - | rs.assignment_id | rs.assignment_id |
| 4 | derived | - | travel_request_id | - | trm.travel_request_id | trm.travel_request_id |
| 5 | derived | - | event_activity | - | CASE WHEN m.is_on_signer IS TRUE THEN 'sign_on'::varchar(50) WHEN m.is_on_signer IS FALSE THEN 'sign_off'::varchar(50) ELSE 'sign_on'::varchar(50) END AS event_activity | CASE WHEN m.is_on_signer IS TRUE THEN 'sign_on'::varchar(50) WHEN m.is_on_signer IS FALSE THEN 'sign_off'::varchar(50) ELSE 'sign_on'::varchar(50) END |
| 6 | derived | - | state | - | 'Open'::varchar(50) AS state | 'Open'::varchar(50) |
| 7 | derived | - | status | - | 'Active'::varchar(50) AS status | 'Active'::varchar(50) |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | created_at | - | COALESCE(m.created_at, NOW()) AS created_at | COALESCE(m.created_at, NOW()) |
| 10 | derived | - | updated_at | - | COALESCE(m.updated_at, m.created_at, NOW()) AS updated_at | COALESCE(m.updated_at, m.created_at, NOW()) |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | derived | - | audit_info | - | m.audit_info | m.audit_info |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Crew Event ID Mapping
**Purpose**: Prerequisites: dblink synergy_manning; public.relief_event_crew_mapping on that database;
**Output columns**: `m.id, m.relief_id, m.event_id, m.seafarer_id, m.is_on_signer, m.created_at, m.updated_at, m.audit_info`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE crew_event_mapping AS
SELECT
    m.id,
    m.relief_id,
    m.event_id,
    m.seafarer_id,
    m.is_on_signer,
    m.created_at,
    m.updated_at,
    m.audit_info
FROM dblink(
    'synergy_manning',
    $SAC$
    SELECT
        id,
        relief_id,
        event_id,
        seafarer_id,
        is_on_signer,
        created_at,
        updated_at,
        audit_info
    FROM public.relief_event_crew_mapping
    WHERE event_id IS NOT NULL
      AND relief_id IS NOT NULL
      AND seafarer_id IS NOT NULL
    $SAC$
) AS m(
    id uuid,
    relief_id bigint,
    event_id uuid,
    seafarer_id bigint,
    is_on_signer boolean,
    created_at timestamp,
    updated_at timestamp,
    audit_info jsonb
);
```

### 2. Event ID Mapping
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

### 3. Travel Request ID Mapping
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

### 4. Relief Id To Travel Request ID Mapping
**Output columns**: `legacy_relief_id, legacy_seafarer_id, legacy_travel_request_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_id_to_travel_request_mapping AS
SELECT DISTINCT ON (ttr.relief_id, ttr.seafarer_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.seafarer_id AS legacy_seafarer_id,
    ttr.id AS legacy_travel_request_id
FROM dblink(
    'synergy_manning',
    $TRAV$
    SELECT ttr.id, ttr.relief_id, ttr.seafarer_id, ttr.created_at
    FROM public.travel_ticket_requests ttr
    INNER JOIN public.travel_tickets tt
        ON tt.relief_id = ttr.relief_id
        AND tt.seafarer_id = ttr.seafarer_id
        AND tt.deleted_at IS NULL
    WHERE ttr.relief_id IS NOT NULL
      AND ttr.seafarer_id IS NOT NULL
      AND ttr.deleted_at IS NULL
    $TRAV$
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint, created_at timestamp)
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.seafarer_id, ttr.created_at DESC NULLS LAST, ttr.id DESC NULLS LAST;
```

Full migration context: `04-migration-scripts/crewing/crew_event_mapping_migration.sql`

## Validation

- Run `05-validation/crewing/crew_event_mapping_validation.sql` if available
- Run `06-rollback/crewing/crew_event_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
