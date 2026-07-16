# Table Mapping: seafarer_signoff_details → sign_off_details

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: sign_off_details
- **Source Script**: `04-migration-scripts/crewing/signoff_details_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_details`
- **New Path**: `smac_crewing_migration.public.sign_off_details`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Signoff Details (`seafarer_signoff_details` → `sign_off_details`)

## Migration Notes

- Source `seafarer_signoff_details` → `public.sign_off_details`
- SAC `uuid` preserved as `id` via `migration.resolve_target_id()` — source_id = bigint `id`, `p_target_id = uuid`
- Pre-migration duplicate UUID check on `uuid` column
- `assignment_id` via `relief_summary_contract_mapping` (INNER JOIN — unmapped contracts excluded)
- `seafarer_id` from `vessel_contracts` via `contract_lookup` + `seafarer_id_mapping`
- `sign_off_port_id` mapped via `port_id_mapping`; `sign_off_reason_id` via master mappings
- `sign_off_sub_reason_id` always NULL (source has no sub-reason)
- Post-INSERT UPDATE: `sign_off_status = 0` for SignOn seafarers where tentative date > recent sign-on
- Filter: `uuid IS NOT NULL`
- Requires `seafarers`, `relief_summary`, `seafarer_vessel_assignments`, ports, sign_off_reasons migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.sign_off_details` before insert (full table reload).
- Orchestration dependencies: `seafarer_contracts`, `vessels`, `seafarers`, `sign_off_reasons`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 9

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `port_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `sign_off_reason_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `sign_off_sub_reason_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `contract_lookup` | Check if any mappings already exist for the given source and target tables (same p | `contract_id`, `vessel_id`, `seafarer_id` | - | `synergy_manning` |
| `relief_summary_contract_mapping` | FK lookup | `DISTINCT ON (rs.contract_id) rs.contract_id`, `rs.assignment_id` | - | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `utc_time_zone_lookup` | FK lookup | `utc_time_zone_id` | - | `smac_master_migration` |
| `profile_state_signon_lookup` | FK lookup | `signon_profile_state_id` | - | `smac_master_migration` |

### `port_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### `sign_off_reason_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_reason_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### `sign_off_sub_reason_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_sub_reason_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_sub_reasons'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### `contract_lookup`

- **Purpose**: Check if any mappings already exist for the given source and target tables (same p
- **Output columns**: contract_id, vessel_id, seafarer_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_lookup AS
SELECT DISTINCT
    vc.id::bigint AS contract_id,
    vc.vessel_id::bigint AS vessel_id,
    vc.seafarer_id::bigint AS seafarer_id
FROM dblink('synergy_manning',
    $$SELECT id, vessel_id, seafarer_id FROM public.vessel_contracts$$
) AS vc(id bigint, vessel_id bigint, seafarer_id bigint);
```

### `relief_summary_contract_mapping`

- **Output columns**: DISTINCT ON (rs.contract_id) rs.contract_id, rs.assignment_id

```sql
CREATE TEMP TABLE relief_summary_contract_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id,
    rs.assignment_id
FROM public.relief_summary rs
INNER JOIN public.seafarer_vessel_assignments sva ON sva.id = rs.assignment_id
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id <> '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### `seafarer_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT DISTINCT ON (source_id::bigint) source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### `utc_time_zone_lookup`

- **Output columns**: utc_time_zone_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE utc_time_zone_lookup AS
SELECT id AS utc_time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE UPPER(TRIM(code)) = ''UTC'' OR UPPER(TRIM(code)) = ''GMT'' OR utc_offset = ''+00:00'' LIMIT 1'
) AS t(id uuid);
```

### `profile_state_signon_lookup`

- **Output columns**: signon_profile_state_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_state_signon_lookup AS
SELECT id AS signon_profile_state_id
FROM dblink('smac_master_migration',
    'SELECT id FROM crewing.profile_states WHERE UPPER(TRIM(code)) = ''SIGNON'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = uuid` | Preserves SAC UUID |
| 2 | `contract_id` → vessel_contracts | bigint | `seafarer_id` | uuid | `contract_lookup` + `seafarer_id_mapping`; nil UUID fallback | |
| 3 | `contract_id` | bigint | `assignment_id` | uuid | Via `relief_summary` INNER JOIN | Required mapping |
| 4 | `sign_off_reason_id` | bigint | `sign_off_reason_id` | uuid | `sign_off_reason_id_mapping`; nil UUID fallback | |
| 5 | — | — | `sign_off_sub_reason_id` | uuid | Always `NULL` | Source has no sub-reason |
| 6 | `sign_off_date` | timestamp without time zone | `tentative_sign_off_date` | date | `CAST(sign_off_date AS date)` | |
| 7 | `sign_off_port_id` | bigint | `tentative_port_id` | uuid | Port map; nil UUID fallback | NOT NULL column |
| 8 | `sign_off_port_id` | bigint | `sign_off_port_id` | uuid | Port map; nullable | |
| 9 | — | — | `sign_off_status` | integer | Default `1`; post-UPDATE to `0` for SignOn | |
| 10 | `sign_off_date` | timestamp without time zone | `sign_off_timestamp_utc` | timestamp without time zone | Direct copy | |
| 11 | `sign_off_date` | timestamp without time zone | `sign_off_timestamp_local` | timestamp without time zone | Same as UTC | |
| 12 | — | — | `sign_off_time_reference` | integer | `NULL` | |
| 13 | `sign_off_note` | text | `remarks` | text | Direct copy | |
| 14 | — | — | `travel_documents_handed_over` | boolean | Hardcoded `false` | |
| 15 | — | — | `confirmed_by` | uuid | `NULL` | `sign_off_confirmed_by` not mapped |
| 16 | — | — | `confirmed_at` | timestamp without time zone | `NULL` | |
| 17 | `deleted_at` | timestamp without time zone | `status` | text | `'Deleted'` / `'Active'` | |
| 18 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 19 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 20 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 21 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 22 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 23 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` | Names not in notes |
| 24 | — | — | `time_zone_id` | uuid | UTC lookup; nil UUID fallback | |
| 25 | `reason` | text | `additional_remarks` | text | Direct copy | |
| 26 | `wages_applicable` | boolean | `wages_applicable` | boolean | `COALESCE(wages_applicable, false)` | |
| 27 | — | — | `onboard_assessment` | boolean | Hardcoded `false` | |
| 28 | — | — | `wages_balance` | boolean | Hardcoded `false` | |
| 29 | — | — | `is_confirmed` | boolean | Hardcoded `false` | |

**SMAC columns not migrated:** `sign_off_sub_reason_id`, `sign_off_time_reference`, `confirmed_by`, `confirmed_at`, `archived_at`, `onboard_assessment`, `wages_balance`, `is_confirmed` — defaults/NULL (not from SAC).

**SAC columns not migrated:** `sign_off_confirmed_by`, `crew_code`, `sign_off_task_id`, `created_by_name`, `updated_by_name` — selected but unused; rows with `uuid IS NULL` or missing relief_summary assignment excluded.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_contracts`
- `seafarers`
- `sign_off_reasons`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Port ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### 2. Sign Off Reason ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_reason_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### 3. Sign Off Sub Reason ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_sub_reason_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_sub_reasons'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### 4. Contract ID Mapping
**Purpose**: Check if any mappings already exist for the given source and target tables (same p
**Output columns**: `contract_id, vessel_id, seafarer_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_lookup AS
SELECT DISTINCT
    vc.id::bigint AS contract_id,
    vc.vessel_id::bigint AS vessel_id,
    vc.seafarer_id::bigint AS seafarer_id
FROM dblink('synergy_manning',
    $$SELECT id, vessel_id, seafarer_id FROM public.vessel_contracts$$
) AS vc(id bigint, vessel_id bigint, seafarer_id bigint);
```

### 5. Relief Summary Contract ID Mapping
**Output columns**: `DISTINCT ON (rs.contract_id) rs.contract_id, rs.assignment_id`

```sql
CREATE TEMP TABLE relief_summary_contract_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id,
    rs.assignment_id
FROM public.relief_summary rs
INNER JOIN public.seafarer_vessel_assignments sva ON sva.id = rs.assignment_id
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id <> '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### 6. Vessel ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### 7. Seafarer ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT DISTINCT ON (source_id::bigint) source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id;
```

### 8. Utc Time Zone ID Mapping
**Output columns**: `utc_time_zone_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE utc_time_zone_lookup AS
SELECT id AS utc_time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE UPPER(TRIM(code)) = ''UTC'' OR UPPER(TRIM(code)) = ''GMT'' OR utc_offset = ''+00:00'' LIMIT 1'
) AS t(id uuid);
```

### 9. Profile State Signon ID Mapping
**Output columns**: `signon_profile_state_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_state_signon_lookup AS
SELECT id AS signon_profile_state_id
FROM dblink('smac_master_migration',
    'SELECT id FROM crewing.profile_states WHERE UPPER(TRIM(code)) = ''SIGNON'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/signoff_details_migration.sql`

## Validation

- Run `05-validation/crewing/signoff_details_validation.sql` if available
- Run `06-rollback/crewing/signoff_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
