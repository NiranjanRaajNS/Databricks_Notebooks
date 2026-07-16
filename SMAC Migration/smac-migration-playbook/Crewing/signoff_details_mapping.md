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

- id via migration.resolve_target_id (legacy bigint id as source_id; preserve legacy uuid when valid — seafarers pattern)
- Map contract_id → assignment_id via public.relief_summary (created by seafarer_vessel_assignments_migration.sql)
- Derive vessel_id and seafarer_id from contract via vessel_contracts table
- Map sign_off_port_id (bigint) → sign_off_port_id (uuid) via migration.table_mappings
- Map sign_off_reason_id (bigint) → sign_off_reason_id (uuid) via migration.table_mappings
- Map sign_off_note → remarks, reason → description
- Uses standardized SMAC audit_info structure
- sign_off_status (integer): updated after INSERT using public.seafarers + crewing.profile_states (master):
- Source table has uuid (uuid) column - check for duplicates
- Migrates seafarer_signoff_details to signoff_details table. Generates new UUIDs for id column (source has bigint, target has uuid). Maps contract_id → seafarer_assignment_id via migration.table_mappings. Derives vessel_id and seafarer_id from contract via vessel_contracts table. Maps sign_off_port_id and sign_off_reason_id via migration.table_mappings. Maps sign_off_note → remarks, reason → description. Uses standardized SMAC audit_info structure. Requires seafarer_contracts, vessels, seafarers, and sign_off_reasons tables to be migrated first.

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
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_signoff_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::V... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(seafarer_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | assignment_id | - | relief_summary.assignment_id AS assignment_id | relief_summary.assignment_id |
| 4 | derived | - | sign_off_reason_id | - | COALESCE(reason_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS sign_off_reason_id | COALESCE(reason_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | sign_off_sub_reason_id | - | sub_reason_mapping.target_id AS sign_off_sub_reason_id | sub_reason_mapping.target_id |
| 6 | sign_off_date | - | tentative_sign_off_date | - | CAST(legacy_data.sign_off_date AS date) AS tentative_sign_off_date | CAST(legacy_data.sign_off_date AS date) |
| 7 | derived | - | tentative_port_id | - | COALESCE(port_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS tentative_port_id | COALESCE(port_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 8 | derived | - | sign_off_port_id | - | port_mapping.target_id AS sign_off_port_id | port_mapping.target_id |
| 9 | derived | - | sign_off_status | - | 1 AS sign_off_status | 1 |
| 10 | sign_off_date | - | sign_off_timestamp_utc | - | legacy_data.sign_off_date AS sign_off_timestamp_utc | legacy_data.sign_off_date |
| 11 | sign_off_date | - | sign_off_timestamp_local | - | legacy_data.sign_off_date AS sign_off_timestamp_local | legacy_data.sign_off_date |
| 12 | - | - | sign_off_time_reference | - | NULL | NULL::integer |
| 13 | sign_off_note | - | remarks | - | legacy_data.sign_off_note AS remarks | legacy_data.sign_off_note |
| 14 | derived | - | travel_documents_handed_over | - | false AS travel_documents_handed_over | false |
| 15 | - | - | confirmed_by | - | NULL | NULL::uuid |
| 16 | - | - | confirmed_at | - | NULL | NULL::timestamp |
| 17 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END |
| 18 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 19 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 20 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 21 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 22 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 23 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |
| 24 | derived | - | time_zone_id | - | COALESCE( utc_tz.utc_time_zone_id, (SELECT utc_time_zone_id FROM utc_time_zone_lookup WHERE utc_time_zone_id IS NOT NULL LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid )... | COALESCE( utc_tz.utc_time_zone_id, (SELECT utc_time_zone_id FROM utc_time_zone_lookup WHERE utc_time_zone_id IS NOT NULL LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 25 | reason | - | additional_remarks | - | legacy_data.reason AS additional_remarks | legacy_data.reason |
| 26 | wages_applicable | - | wages_applicable | - | COALESCE(legacy_data.wages_applicable, false) AS wages_applicable | COALESCE(legacy_data.wages_applicable, false) |
| 27 | derived | - | onboard_assessment | - | false AS onboard_assessment | false |
| 28 | derived | - | wages_balance | - | false AS wages_balance | false |
| 29 | derived | - | is_confirmed | - | false AS is_confirmed | false |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`

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
