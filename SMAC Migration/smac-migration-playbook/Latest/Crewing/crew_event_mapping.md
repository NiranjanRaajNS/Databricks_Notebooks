# Table Mapping: relief_event_crew_mapping → crew_event_assignments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: relief_event_crew_mapping
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crew_event_assignments
- **Source Script**: `04-migration-scripts/crewing/crew_event_mapping_migration.sql`

- **Legacy Path**: `synergy_manning.public.relief_event_crew_mapping`
- **New Path**: `smac_crewing_migration.public.crew_event_assignments`

## Business Key

- **Composite Key**: (`event_id`, `assignment_id`)
- **Source (orchestration)**: Relief event crew mapping (Manning) (`relief_event_crew_mapping` → `crew_event_assignments`, group: CrewingSeafarersManning)

## Migration Notes

- SAC source loaded via dblink into temp table `crew_event_mapping` from `synergy_manning.public.relief_event_crew_mapping`
- Source `id` (uuid) — uses `migration.resolve_target_id()` with `p_target_id = NULL` (idempotent UUID per mapping row)
- `event_id` mapped via `event_id_mapping` from `migration.table_mappings` where `target_table = 'crew_relief_events'`
- `assignment_id` derived from `public.relief_summary` — join on `seafarer_id` and (`planned_relief_id` OR `onboard_relief_id`) = `relief_id`; requires `relief_summary` from `seafarer_vessel_assignments` migration
- `travel_request_id` (nullable): `travel_ticket_requests` INNER JOIN `travel_tickets` on `relief_id` + `seafarer_id` (`travel_tickets.deleted_at IS NULL`), then `travel_request_id_mapping` → `crewing_travel_requests`
- `event_activity` derived from `is_on_signer` boolean (`true` → `sign_on`, `false` → `sign_off`)
- `audit_info` copied directly from SAC `audit_info` JSONB column
- Filter: `event_id`, `relief_id`, and `seafarer_id` must all be NOT NULL
- `DISTINCT ON (m.id)` with `relief_summary` ordered by `relief_created_at DESC` when multiple assignment matches exist
- Pre-migration: deletes orphan `migration.table_mappings` rows for `crew_event_assignments` sourced from `synergy_seafarer.relief_event_crew_mapping` and `synergy_manning.crew_relief_event`
- Script performs `TRUNCATE TABLE public.crew_event_assignments` before insert (full table reload)

## Special Considerations

- Requires dblink connection to `synergy_manning` and table `public.relief_event_crew_mapping` on that database
- Requires `public.relief_summary` table (populated by `seafarer_vessel_assignments` migration)
- Orchestration dependencies: `crew_relief_events`, `seafarer_vessel_assignments`, `crewing_travel_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script.

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|----------------------------------|--------|
| `crew_event_mapping` | Staging — SAC `relief_event_crew_mapping` rows | `id`, `relief_id`, `event_id`, `seafarer_id`, `is_on_signer`, `created_at`, `updated_at`, `audit_info` | — | `synergy_manning` |
| `event_id_mapping` | FK lookup — legacy event uuid → SMAC `crew_relief_events.id` | `legacy_event_id`, `event_id` | `crew_relief_events` | — |
| `travel_request_id_mapping` | FK lookup — legacy travel request id → SMAC `crewing_travel_requests.id` | `legacy_travel_request_id`, `travel_request_id` | `crewing_travel_requests` | — |
| `relief_id_to_travel_request_mapping` | Resolve travel request by relief + seafarer | `legacy_relief_id`, `legacy_seafarer_id`, `legacy_travel_request_id` | — | `synergy_manning` |

### `crew_event_mapping`

- **Purpose**: Stage SAC `relief_event_crew_mapping` rows for migration
- **Output columns**: id, relief_id, event_id, seafarer_id, is_on_signer, created_at, updated_at, audit_info
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
- **migration.table_mappings**: target_table = `crew_relief_events`

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
- **migration.table_mappings**: target_table = `crewing_travel_requests`

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_db = `synergy_manning`; source_table = `relief_event_crew_mapping`; source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID per SAC mapping row |
| 2 | `event_id` | uuid | `event_id` | uuid | Map via `event_id_mapping`; `INNER JOIN` on `legacy_event_id = event_id::text` | Lookup: `migration.table_mappings` where `target_table = 'crew_relief_events'`; unmapped rows excluded |
| 3 | `relief_id`, `seafarer_id` | bigint, bigint | `assignment_id` | uuid | `INNER JOIN public.relief_summary` on `seafarer_id` and (`planned_relief_id` OR `onboard_relief_id`) = `relief_id`; `assignment_id` NOT NULL and not nil UUID | Requires `relief_summary` from `seafarer_vessel_assignments` migration; `DISTINCT ON (m.id)` picks latest `relief_created_at` |
| 4 | `relief_id`, `seafarer_id` | bigint, bigint | `travel_request_id` | uuid | `LEFT JOIN relief_id_to_travel_request_mapping` → `travel_request_id_mapping` on legacy travel request id | Nullable; `travel_ticket_requests` INNER JOIN `travel_tickets` where tickets not deleted |
| 5 | `is_on_signer` | boolean | `event_activity` | character varying(50) | `TRUE` → `'sign_on'`; `FALSE` → `'sign_off'`; NULL → `'sign_on'` | NOT NULL in SMAC |
| 6 | — | — | `state` | character varying(50) | Hardcoded `'Open'` | SMAC default; not in SAC source |
| 7 | — | — | `status` | character varying(50) | Hardcoded `'Active'` | SMAC default; not in SAC source |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 10 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 11 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source; all migrated rows active |
| 12 | `audit_info` | jsonb | `audit_info` | jsonb | Direct copy  | SAC JSONB preserved as-is on SMAC row |

**SAC columns not migrated:** `relief_id`, `seafarer_id` — used only for FK joins (`relief_summary`, travel request lookup), not stored as SMAC columns.

**SMAC columns not migrated:** None beyond defaults above.

**Source filter:** Rows where `event_id`, `relief_id`, and `seafarer_id` are all NOT NULL.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crew_relief_events`
- `seafarer_vessel_assignments` (provides `public.relief_summary`)
- `crewing_travel_requests`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables.

### 1. SAC Staging (`crew_event_mapping`)
**Purpose**: Load `synergy_manning.public.relief_event_crew_mapping` via dblink  
**dblink**: `synergy_manning`

See SQL under **ID Mappings → `crew_event_mapping`** above.

### 2. Event ID Mapping
**Output columns**: `legacy_event_id`, `event_id`  
**migration.table_mappings**: `target_table = 'crew_relief_events'`

See SQL under **ID Mappings → `event_id_mapping`** above.

### 3. Travel Request ID Mapping
**Output columns**: `legacy_travel_request_id`, `travel_request_id`  
**migration.table_mappings**: `target_table = 'crewing_travel_requests'`

See SQL under **ID Mappings → `travel_request_id_mapping`** above.

### 4. Relief to Travel Request Mapping
**Output columns**: `legacy_relief_id`, `legacy_seafarer_id`, `legacy_travel_request_id`  
**dblink**: `synergy_manning` (`travel_ticket_requests` + `travel_tickets`)

See SQL under **ID Mappings → `relief_id_to_travel_request_mapping`** above.

Full migration context: `04-migration-scripts/crewing/crew_event_mapping_migration.sql`

## Validation

- Run `05-validation/crewing/crew_event_assignments_validation.sql` if available
- Run `06-rollback/crewing/crew_event_assignments_rollback.sql` if rollback is required

## Document Status

Reviewed against `crew_event_mapping_migration.sql` and `migration_config_smac_crewing.json` (group: CrewingSeafarersManning).
