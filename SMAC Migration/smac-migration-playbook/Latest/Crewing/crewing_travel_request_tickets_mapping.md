# Table Mapping: travel_ticket_details → crewing_travel_request_tickets

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: travel_ticket_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crewing_travel_request_tickets
- **Source Script**: `04-migration-scripts/crewing/crewing_travel_request_tickets_migration.sql`

- **Legacy Path**: `synergy_manning.public.travel_ticket_details`
- **New Path**: `smac_crewing_migration.public.crewing_travel_request_tickets`

## Business Key

- **Composite Key**: (`travel_request_id`, `segment_order`)
- **Source (orchestration)**: Crewing Travel Request Tickets (`travel_ticket_details` → `crewing_travel_request_tickets`)

## Migration Notes

- Migrates travel_ticket_details to crewing_travel_request_tickets. Generates new UUID for id. Maps travel_ticket_id to travel_request_id. Calculates segment_order using ROW_NUMBER. Combines departure_date/departure_time and arrival_date/arrival_time into departure_at and arrival_at.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crewing_travel_request_tickets` before insert (full table reload).
- Orchestration dependencies: `crewing_travel_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `travel_request_id_mapping` | FK lookup | `legacy_travel_ticket_id`, `travel_request_id`, `from_city`, `to_city`, `number_of_stops` | `?.?.travel_ticket_requests` → `?.?.crewing_travel_requests` | `synergy_manning` |
| `travel_request_attachments_mapping` | Travel request ID mapping via travel_tickets → travel_ticket_requests → crewing_travel_requests | `travel_request_id`, `attachment_ids` | - | - |

### `travel_request_id_mapping`

- **Output columns**: legacy_travel_ticket_id, travel_request_id, from_city, to_city, number_of_stops
- **migration.table_mappings**: source_table=travel_ticket_requests, target_table=crewing_travel_requests
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT DISTINCT ON (tt.id)
    tt.id AS legacy_travel_ticket_id,
    tr_map.target_id AS travel_request_id,
    TRIM(tt.from_city) AS from_city,
    TRIM(tt.to_city) AS to_city,
    COALESCE(tt.number_of_stops, 0) AS number_of_stops
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id, from_city, to_city, number_of_stops FROM public.travel_tickets WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS tt(id bigint, relief_id bigint, seafarer_id bigint, from_city text, to_city text, number_of_stops integer)
JOIN dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
    ON ttr.relief_id = tt.relief_id AND ttr.seafarer_id = tt.seafarer_id
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE tt.relief_id IS NOT NULL
  AND tt.seafarer_id IS NOT NULL
ORDER BY t...
```

### `travel_request_attachments_mapping`

- **Purpose**: Travel request ID mapping via travel_tickets → travel_ticket_requests → crewing_travel_requests
- **Output columns**: travel_request_id, attachment_ids

```sql
CREATE TEMP TABLE travel_request_attachments_mapping AS
SELECT
    travel_request_id,
    ARRAY_AGG(id ORDER BY id) FILTER (WHERE id IS NOT NULL) AS attachment_ids
FROM public.crewing_travel_request_attachments
WHERE travel_request_id IS NOT NULL
GROUP BY travel_request_id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID per ticket detail row |
| 2 | `travel_ticket_id` | bigint | `travel_request_id` | uuid | Map via `travel_request_id_mapping`; default nil UUID | Lookup: `crewing_travel_requests` |
| 3 | `travel_ticket_id`, `departure_date`, `departure_time` | bigint, timestamp | `segment_order` | integer | Direct journey → 0; else `ROW_NUMBER()` per ticket ordered by departure | NOT NULL |
| 4 | `travel_tickets.from_city` | — | `from_city` | text | From `travel_request_id_mapping` join | From parent travel ticket |
| 5 | `travel_tickets.to_city` | — | `to_city` | text | From `travel_request_id_mapping` join | From parent travel ticket |
| 6 | `from_airport` | text | `departure_airport` | text | `TRIM(from_airport)` | Nullable |
| 7 | `to_airport` | text | `arrival_airport` | text | `TRIM(to_airport)` | Nullable |
| 8 | `departure_date` | timestamp without time zone | `departure_at` | timestamp without time zone | Cast to timestamp | NOT NULL |
| 9 | `arrival_date` | date | `arrival_at` | timestamp without time zone | Cast date → timestamp | Nullable |
| 10 | `flight_number` | text | `flight_number` | text | `TRIM(flight_number)` | Nullable |
| 11 | `airlines_name` | text | `airline_name` | text | `TRIM(airlines_name)` | Nullable |
| 12 | `pnr` | text | `pnr_number` | text | `TRIM(pnr)` | Nullable |
| 13 | `travel_request_id` (mapped) | uuid | `attachment_id` | uuid[] | Aggregated attachment UUIDs from `travel_request_attachments_mapping` | Default empty array |
| 14 | — | — | `ticket_status` | character varying(30) | Hardcoded `'ISSUED'` | SMAC default |
| 15 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `Deleted`; else `Active` | NOT NULL |
| 16 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 17 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 18 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Direct copy | Nullable |
| 19 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 20 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text, character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | Standardized SMAC audit |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `departure_time` — used only for `segment_order` ordering, not stored as separate SMAC column.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing_travel_requests`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Travel Request ID Mapping
**Output columns**: `legacy_travel_ticket_id, travel_request_id, from_city, to_city, number_of_stops`
**migration.table_mappings**: `travel_ticket_requests` → `crewing_travel_requests`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT DISTINCT ON (tt.id)
    tt.id AS legacy_travel_ticket_id,
    tr_map.target_id AS travel_request_id,
    TRIM(tt.from_city) AS from_city,
    TRIM(tt.to_city) AS to_city,
    COALESCE(tt.number_of_stops, 0) AS number_of_stops
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id, from_city, to_city, number_of_stops FROM public.travel_tickets WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS tt(id bigint, relief_id bigint, seafarer_id bigint, from_city text, to_city text, number_of_stops integer)
JOIN dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
    ON ttr.relief_id = tt.relief_id AND ttr.seafarer_id = tt.seafarer_id
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE tt.relief_id IS NOT NULL
  AND tt.seafarer_id IS NOT NULL
ORDER BY tt.id, tr_map.target_id;
```

### 2. Travel Request Attachments ID Mapping
**Purpose**: Travel request ID mapping via travel_tickets → travel_ticket_requests → crewing_travel_requests
**Output columns**: `travel_request_id, attachment_ids`

```sql
CREATE TEMP TABLE travel_request_attachments_mapping AS
SELECT
    travel_request_id,
    ARRAY_AGG(id ORDER BY id) FILTER (WHERE id IS NOT NULL) AS attachment_ids
FROM public.crewing_travel_request_attachments
WHERE travel_request_id IS NOT NULL
GROUP BY travel_request_id;
```

Full migration context: `04-migration-scripts/crewing/crewing_travel_request_tickets_migration.sql`

## Validation

- Run `05-validation/crewing/crewing_travel_request_tickets_validation.sql` if available
- Run `06-rollback/crewing/crewing_travel_request_tickets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
