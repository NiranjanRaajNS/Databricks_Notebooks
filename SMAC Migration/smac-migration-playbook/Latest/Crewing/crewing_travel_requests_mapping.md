# Table Mapping: travel_ticket_requests → crewing_travel_requests

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: travel_ticket_requests
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crewing_travel_requests
- **Source Script**: `04-migration-scripts/crewing/crewing_travel_requests_migration.sql`

- **Legacy Path**: `synergy_manning.public.travel_ticket_requests`
- **New Path**: `smac_crewing_migration.public.crewing_travel_requests`

## Business Key

- **Composite Key**: (`seafarer_id`, `assignment_id`, `departure_date`)
- **Source (orchestration)**: Crewing Travel Requests (`travel_ticket_requests` → `crewing_travel_requests`)

## Migration Notes

- SAC `travel_ticket_requests` → SMAC `crewing_travel_requests`
- `migration.resolve_target_id()` with `p_target_id = NULL` (SAC bigint `id`)
- `seafarer_id` via `seafarer_id_mapping`; `assignment_id` from `relief_summary` or nil UUID
- `travel_type_id` from `travel_tickets.status` via `travel_types_mapping`; `preferred_time_slot_id` from `travel_time` enum
- `travel_ticket_status` derived: tickets exist → TICKET_ISSUED; else email sent → EMAIL_SENT; else PENDING_APPROVAL
- `agent_id` from `agent_id_mapping` (seafarer_id + relief_id match)
- Requires `seafarers`, `relief_summary`, `travel_types` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.crewing_travel_requests` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `travel_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `agent_id_mapping` | FK lookup | `legacy_seafarer_id`, `legacy_relief_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_manning` |
| `travel_types_mapping` | Fallback as | `travel_type_code`, `travel_type_uuid` | - | `smac_master_migration` |
| `travel_time_slots_mapping` | Fallback assignment ID mapping (seafarer_id → most recent seafarer_vessel_assignments.id) | `time_slot_uuid`, `time_slot_code`, `time_slot_name` | - | `smac_master_migration` |
| `travel_time_enum_mapping` | COMMENTED OUT: Fallback assignment mapping logic disabled | `travel_time_enum::integer`, `expected_code::text` | - | - |
| `travel_tickets_mapping` | COMMENTED OUT: Diagnostic block disabled since assignment_id_f | `legacy_relief_id`, `ticket_status`, `arrival_date`, `travel_type_code` | - | `synergy_manning` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `agent_id_mapping`

- **Output columns**: legacy_seafarer_id, legacy_relief_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT DISTINCT ON (al.seafarer_id, al.relief_id)
    al.seafarer_id AS legacy_seafarer_id,
    al.relief_id AS legacy_relief_id,
    agent_tm.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT seafarer_id, relief_id, agent_id FROM public.agent_letters WHERE seafarer_id IS NOT NULL AND relief_id IS NOT NULL'
) AS al(
    seafarer_id bigint,
    relief_id bigint,
    agent_id bigint
)
INNER JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''agents''
     AND target_db = ''smac_master_migration''
     AND source_id ~ ''^[0-9]+$'''
) AS agent_tm(
    source_id text,
    target_id uuid
) ON agent_tm.source_id::bigint = al.agent_id
ORDER BY al.seafarer_id, al.relief_id, agent_tm.target_id;
```

### `travel_types_mapping`

- **Purpose**: Fallback as
- **Output columns**: travel_type_code, travel_type_uuid
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_types_mapping AS
SELECT
    tt.code::text as travel_type_code,
    tt.id as travel_type_uuid
FROM dblink('smac_master_migration',
    'SELECT id, code
     FROM crewing.travel_types
     WHERE code IS NOT NULL'
) AS tt(id uuid, code text)
WHERE tt.code IS NOT NULL;
```

### `travel_time_slots_mapping`

- **Purpose**: Fallback assignment ID mapping (seafarer_id → most recent seafarer_vessel_assignments.id)
- **Output columns**: time_slot_uuid, time_slot_code, time_slot_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_time_slots_mapping AS
SELECT
    tts.id as time_slot_uuid,
    tts.code::text as time_slot_code,
    tts.name::text as time_slot_name
FROM dblink('smac_master_migration',
    'SELECT id, code, name
     FROM crewing.travel_time_slots
     WHERE code IS NOT NULL'
) AS tts(id uuid, code text, name text)
WHERE tts.code IS NOT NULL;
```

### `travel_time_enum_mapping`

- **Purpose**: COMMENTED OUT: Fallback assignment mapping logic disabled
- **Output columns**: travel_time_enum::integer, expected_code::text

```sql
CREATE TEMP TABLE travel_time_enum_mapping AS
SELECT
    travel_time_enum::integer,
    expected_code::text
FROM (VALUES
    (0::integer, 'BEFORE_6AM'::text),
    (1::integer, 'MORNING_6_TO_12'::text),
    (2::integer, NULL::text),
    (3::integer, 'EVENING_AFTER_18'::text),
    (4::integer, 'ANY_TIME'::text)
) AS enum_map(travel_time_enum, expected_code);
```

### `travel_tickets_mapping`

- **Purpose**: COMMENTED OUT: Diagnostic block disabled since assignment_id_f
- **Output columns**: legacy_relief_id, ticket_status, arrival_date, travel_type_code
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_tickets_mapping AS
SELECT DISTINCT ON (tt.relief_id)
    tt.relief_id AS legacy_relief_id,
    tt.status AS ticket_status,
    tt.arrival_date AS arrival_date,

    CASE
        WHEN tt.status = 0 THEN 'NO_NEED'
        WHEN tt.status = 1 THEN 'DOMESTIC'
        WHEN tt.status = 2 THEN 'INTERNATIONAL'
        ELSE NULL
    END AS travel_type_code
FROM dblink('synergy_manning',
    'SELECT relief_id, status, created_at, arrival_date
     FROM public.travel_tickets
     WHERE relief_id IS NOT NULL
     AND deleted_at IS NULL'
) AS tt(
    relief_id bigint,
    status integer,
    created_at timestamp,
    arrival_date date
)
WHERE tt.relief_id IS NOT NULL
ORDER BY tt.relief_id, (tt.arrival_date IS NOT NULL) DESC, tt.created_at DESC NULLS LAST;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | `DISTINCT ON (id)` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping` | Lookup: `seafarers`; NOT NULL |
| 3 | `relief_id` | bigint | `assignment_id` | uuid | `relief_summary.assignment_id` or nil UUID | Lookup: `relief_summary` by planned/onboard relief |
| 4 | — | — | `assignment_activity` | character varying(20) | Hardcoded `'Onboarding'` | SMAC default |
| 5 | `travel_tickets.status` (via relief) | — | `travel_type_id` | uuid | Map ticket status code via `travel_types_mapping` | Lookup: dblink `travel_types` |
| 6 | `from_city` | character varying | `from_place` | jsonb | `jsonb_build_object('City', TRIM(from_city))` | NOT NULL |
| 7 | `to_city` | character varying | `to_place` | jsonb | `jsonb_build_object('City', TRIM(to_city))` | NOT NULL |
| 8 | `departure_time` | timestamp without time zone | `departure_date` | date | Cast timestamp → date | NOT NULL |
| 9 | `travel_time` | integer | `preferred_time_slot_id` | uuid | Enum → code via `travel_time_enum_mapping` → `travel_time_slots_mapping` | Lookup: dblink master |
| 10 | — | — | `remarks` | text | `NULL` | No equivalent in SAC |
| 11 | `email_sent_at`, `relief_id` | timestamp, bigint | `travel_ticket_status` | character varying(30) | Tickets exist → TICKET_ISSUED; email sent → EMAIL_SENT; else PENDING_APPROVAL | Derived priority rule |
| 12 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `Deleted`; else `Active` | NOT NULL |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Direct copy | Nullable |
| 16 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 17 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | timestamp, character varying | `audit_info` | jsonb | `migration.build_audit_info()` — invalid created/updated IDs use `SYSTEM_USER_ID` from `constants.sql` | SAC stores some IDs as timestamps |
| 18 | `seafarer_id`, `relief_id` | bigint | `agent_id` | uuid | Map via `agent_id_mapping` | Lookup: agent letters join |
| 19 | — | — | `document_status` | text | Hardcoded `'PENDING'` | SMAC default |
| 20 | `email_sent_at` | timestamp without time zone | `send_to_seafarer` | boolean | `email_sent_at IS NOT NULL` → true | NOT NULL |
| 21 | `email_sent_at` | timestamp without time zone | `travel_agent_status` | character varying(30) | Email sent → EMAIL_SENT; else PENDING_APPROVAL | NOT NULL |
| 22 | `travel_tickets.arrival_date` | date | `arrival_date` | date | From `travel_tickets_mapping` by `relief_id` | Nullable |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `travel_mode`, `travel_date` — not referenced in migration INSERT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_vessel_assignments`
- `seafarers`
- `travel_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Agent ID Mapping
**Output columns**: `legacy_seafarer_id, legacy_relief_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT DISTINCT ON (al.seafarer_id, al.relief_id)
    al.seafarer_id AS legacy_seafarer_id,
    al.relief_id AS legacy_relief_id,
    agent_tm.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT seafarer_id, relief_id, agent_id FROM public.agent_letters WHERE seafarer_id IS NOT NULL AND relief_id IS NOT NULL'
) AS al(
    seafarer_id bigint,
    relief_id bigint,
    agent_id bigint
)
INNER JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''agents''
     AND target_db = ''smac_master_migration''
     AND source_id ~ ''^[0-9]+$'''
) AS agent_tm(
    source_id text,
    target_id uuid
) ON agent_tm.source_id::bigint = al.agent_id
ORDER BY al.seafarer_id, al.relief_id, agent_tm.target_id;
```

### 3. Travel Types ID Mapping
**Purpose**: Fallback as
**Output columns**: `travel_type_code, travel_type_uuid`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_types_mapping AS
SELECT
    tt.code::text as travel_type_code,
    tt.id as travel_type_uuid
FROM dblink('smac_master_migration',
    'SELECT id, code
     FROM crewing.travel_types
     WHERE code IS NOT NULL'
) AS tt(id uuid, code text)
WHERE tt.code IS NOT NULL;
```

### 4. Travel Time Slots ID Mapping
**Purpose**: Fallback assignment ID mapping (seafarer_id → most recent seafarer_vessel_assignments.id)
**Output columns**: `time_slot_uuid, time_slot_code, time_slot_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_time_slots_mapping AS
SELECT
    tts.id as time_slot_uuid,
    tts.code::text as time_slot_code,
    tts.name::text as time_slot_name
FROM dblink('smac_master_migration',
    'SELECT id, code, name
     FROM crewing.travel_time_slots
     WHERE code IS NOT NULL'
) AS tts(id uuid, code text, name text)
WHERE tts.code IS NOT NULL;
```

### 5. Travel Time Enum ID Mapping
**Purpose**: COMMENTED OUT: Fallback assignment mapping logic disabled
**Output columns**: `travel_time_enum::integer, expected_code::text`

```sql
CREATE TEMP TABLE travel_time_enum_mapping AS
SELECT
    travel_time_enum::integer,
    expected_code::text
FROM (VALUES
    (0::integer, 'BEFORE_6AM'::text),
    (1::integer, 'MORNING_6_TO_12'::text),
    (2::integer, NULL::text),
    (3::integer, 'EVENING_AFTER_18'::text),
    (4::integer, 'ANY_TIME'::text)
) AS enum_map(travel_time_enum, expected_code);
```

### 6. Travel Tickets ID Mapping
**Purpose**: COMMENTED OUT: Diagnostic block disabled since assignment_id_f
**Output columns**: `legacy_relief_id, ticket_status, arrival_date, travel_type_code`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_tickets_mapping AS
SELECT DISTINCT ON (tt.relief_id)
    tt.relief_id AS legacy_relief_id,
    tt.status AS ticket_status,
    tt.arrival_date AS arrival_date,

    CASE
        WHEN tt.status = 0 THEN 'NO_NEED'
        WHEN tt.status = 1 THEN 'DOMESTIC'
        WHEN tt.status = 2 THEN 'INTERNATIONAL'
        ELSE NULL
    END AS travel_type_code
FROM dblink('synergy_manning',
    'SELECT relief_id, status, created_at, arrival_date
     FROM public.travel_tickets
     WHERE relief_id IS NOT NULL
     AND deleted_at IS NULL'
) AS tt(
    relief_id bigint,
    status integer,
    created_at timestamp,
    arrival_date date
)
WHERE tt.relief_id IS NOT NULL
ORDER BY tt.relief_id, (tt.arrival_date IS NOT NULL) DESC, tt.created_at DESC NULLS LAST;
```

Full migration context: `04-migration-scripts/crewing/crewing_travel_requests_migration.sql`

## Validation

- Run `05-validation/crewing/crewing_travel_requests_validation.sql` if available
- Run `06-rollback/crewing/crewing_travel_requests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
