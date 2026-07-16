# Table Mapping: vessel_contracts → sign_on_details

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: vessel_contracts
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: sign_on_details
- **Source Script**: `04-migration-scripts/crewing/seafarer_signon_details_migration.sql`

- **Legacy Path**: `synergy_manning.public.vessel_contracts`
- **New Path**: `smac_crewing_migration.public.sign_on_details`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Sign On Details (`vessel_contracts` → `sign_on_details`)

## Migration Notes

- Source `synergy_manning.public.vessel_contracts` → `public.sign_on_details`
- SAC `uuid` preserved as `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `assignment_id` resolved from `relief_summary` via `contract_id` mapping
- `seafarer_id`, `port_id` mapped via `migration.table_mappings`; nil UUID fallbacks
- Filter: `status IN ('INFORCE','CLOSED')`, `sign_on_date IS NOT NULL`, `in_cancellation = false`, `deleted_at IS NULL`
- `remarks` intentionally set NULL (source remarks are cancellation-only)
- `time_zone_id` from UTC lookup in `smac_master_migration.time_zones`
- Requires `seafarers`, `relief_summary`, `seafarer_vessel_assignments`, ports migrated first

## Special Considerations

- Extract remarks value only from JSONB (ignore key)
- Script performs `TRUNCATE TABLE public.sign_on_details` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `ports`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `port_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `assignment_id_mapping` | Check if | `legacy_contract_id`, `assignment_id` | - | - |
| `utc_time_zone_lookup` | FK lookup | `utc_time_zone_id` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `port_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### `assignment_id_mapping`

- **Purpose**: Check if
- **Output columns**: legacy_contract_id, assignment_id

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id::bigint AS legacy_contract_id,
    rs.assignment_id AS assignment_id
FROM public.relief_summary rs
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### `utc_time_zone_lookup`

- **Output columns**: utc_time_zone_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE utc_time_zone_lookup AS
SELECT id AS utc_time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE UPPER(TRIM(code)) = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC UUID |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID fallback | |
| 3 | `id` (contract) | bigint | `assignment_id` | uuid | Via `relief_summary.contract_id` → `assignment_id`; nil UUID fallback | |
| 4 | `sign_on_date` | timestamp without time zone | `sign_on_timestamp_utc` | timestamp without time zone | `CAST(sign_on_date AS timestamp)` | |
| 5 | `sign_on_date` | timestamp without time zone | `sign_on_timestamp_local` | timestamp without time zone | Same as UTC | No separate local timestamp in SAC |
| 6 | `port_of_sign_on` | text | `port_id` | uuid | Map via `port_id_mapping` (cast to bigint); nil UUID fallback | |
| 7 | `start_date` | timestamp without time zone | `travel_start_date` | timestamp without time zone | `CAST(start_date AS timestamp)` | |
| 8 | `remarks` | jsonb | `remarks` | text | Hardcoded `NULL` | - |
| 9 | — | — | `status` | integer | Hardcoded `0` (Active) | Source filtered to non-deleted |
| 10 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 13 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` | |
| 14 | — | — | `time_zone_id` | uuid | UTC timezone lookup; nil UUID fallback | From `smac_master_migration.time_zones` |
| 15 | — | — | `is_confirmed` | boolean | Hardcoded `false` | |
| 16 | — | — | `sign_on_time_reference` | integer | Hardcoded `0` | |

**SMAC columns not migrated:** None — all target columns populated or defaulted.

**SAC columns not migrated:** `remarks` (forced NULL); `created_by_name`, `updated_by_name` — selected but not used as separate SMAC columns.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ports`
- `seafarer_vessel_assignments`
- `seafarers`

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
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Port ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### 3. Assignment ID Mapping
**Purpose**: Check if
**Output columns**: `legacy_contract_id, assignment_id`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id::bigint AS legacy_contract_id,
    rs.assignment_id AS assignment_id
FROM public.relief_summary rs
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### 4. Utc Time Zone ID Mapping
**Output columns**: `utc_time_zone_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE utc_time_zone_lookup AS
SELECT id AS utc_time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE UPPER(TRIM(code)) = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_signon_details_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_signon_details_validation.sql` if available
- Run `06-rollback/crewing/seafarer_signon_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
