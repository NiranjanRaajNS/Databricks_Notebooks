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

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `vessel_id` mapped via `vessel_id_mapping` (dblink `smac_master_migration`)
- `event_port_id` / `port_call_id` extracted from JSONB `PortId` → `ports` mapping
- `port_agent_id` extracted from JSONB `Id` → `agents` mapping
- `event_type` hardcoded `'Scheduled'`; `event_status` from SAC `status` (Closed→Completed)
- Requires `vessels`, `ports`, `agents` migrated in master DB first

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` | Lookup: `vessels` (dblink); NOT NULL |
| 3 | `event_code` | character varying | `event_code` | text | `TRIM(event_code)` | NOT NULL |
| 4 | `event_name` | character varying | `event_name` | text | `TRIM(event_name)` | NOT NULL |
| 5 | — | — | `event_type` | character varying(50) | Hardcoded `'Scheduled'` | SMAC default |
| 6 | `status` | character varying | `event_status` | character varying(50) | `Closed` → `Completed`; else `Planned` | Derived from SAC status text |
| 7 | `start_date` | date | `start_date` | timestamp without time zone | Cast date → timestamp | NOT NULL |
| 8 | `end_date` | date | `end_date` | timestamp without time zone | Cast date → timestamp | NOT NULL |
| 9 | `eta` | timestamp without time zone | `eta` | timestamp without time zone | Direct copy | Nullable |
| 10 | `eta_source` | character varying | `eta_source` | text | `TRIM(eta_source)` | Nullable |
| 11 | `is_eta_mismatch` | boolean | `is_eta_mismatch` | boolean | Direct copy | Nullable |
| 12 | `event_port` (JSONB) → `PortId` | jsonb | `event_port_id` | uuid | Extract numeric `PortId`; map via `port_id_mapping` | Lookup: `ports` |
| 13 | `port_call` (JSONB) → `PortId` | jsonb | `port_call_id` | uuid | Extract numeric `PortId`; map via `port_id_mapping` | Lookup: `ports` |
| 14 | `nearest_airport` | character varying | `nearest_airport` | text | `TRIM(nearest_airport)` | Nullable |
| 15 | `port_agent` (JSONB) → `Id` | jsonb | `port_agent_id` | uuid | Extract numeric `Id`; map via `port_agent_id_mapping` | Lookup: `agents` |
| 16 | `remarks` | character varying | `remarks` | text | `TRIM(remarks)` | Nullable |
| 17 | `closure_remarks` | character varying | `closure_remarks` | text | `TRIM(closure_remarks)` | Nullable |
| 18 | `is_active` | boolean | `status` | character varying(50) | `is_active = true` → `Active`; else `Inactive` | Text status |
| 19 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 20 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 21 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | NOT NULL |
| 22 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC uses `is_active`/`status`, no `deleted_at` |
| 23 | `audit_info` → created/updated by | jsonb, character varying | `audit_info` | jsonb | `migration.build_audit_info()` — fields from SAC `audit_info` JSONB keys | Names in `notes` |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** Full `event_port`, `port_call`, `port_agent` JSONB blobs — only `PortId`/`Id` extracted for FK mapping; remaining JSONB fields not stored in SMAC.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `agents`
- `ports`
- `vessels`

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
