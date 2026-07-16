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

- Filter: Only migrate records where status = 'InForce' AND deleted_at IS NULL
- Map id via migration.resolve_target_id() (preserves legacy uuid when available)
- Map assignment_id via relief_summary table (relief_summary.contract_id = vessel_contracts.id → relief_summary.assignment_id)
- Map seafarer_id via migration.table_mappings (seafarers)
- Map port_of_sign_on via migration.table_mappings (ports from smac_master_migration)
- Map sign_on_date → sign_on_timestamp_utc and sign_on_timestamp_local (single source column)
- Map start_date → travel_start_date (datetime column, handle NULL)
- Get time_zone_id from smac_master_migration.public.time_zones WHERE code = 'UTC'
- Uses standardized SMAC audit_info structure
- Migrates vessel_contracts to sign_on_details table. Filter: Only migrates records where status = 'InForce' AND deleted_at IS NULL. Maps id via seafarer_vessel_assignments.audit_info->>'legacy_contract_id' → seafarer_vessel_assignments.id. Maps seafarer_id via migration.table_mappings (seafarers). Maps port_id via migration.table_mappings (ports from smac_master_migration). Gets time_zone_id from smac_master_migration.public.time_zones WHERE code = 'UTC'. Extracts remarks value only from JSONB (ignore key). Sets status to 0 (Active), travel_start_date to NULL, is_confirmed to false. Uses standardized SMAC audit_info structure. Requires seafarers, seafarer_vessel_assignments, and ports tables to be migrated first.

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
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_contracts'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | assignment_id | - | COALESCE( assignment_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS assignment_id | COALESCE( assignment_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | sign_on_date | - | sign_on_timestamp_utc | - | CAST(legacy_data.sign_on_date AS timestamp) AS sign_on_timestamp_utc | CAST(legacy_data.sign_on_date AS timestamp) |
| 5 | sign_on_date | - | sign_on_timestamp_local | - | CAST(legacy_data.sign_on_date AS timestamp) AS sign_on_timestamp_local | CAST(legacy_data.sign_on_date AS timestamp) |
| 6 | derived | - | port_id | - | COALESCE( port_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS port_id | COALESCE( port_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 7 | start_date | - | travel_start_date | - | CAST(legacy_data.start_date AS timestamp) AS travel_start_date | CAST(legacy_data.start_date AS timestamp) |
| 8 | derived | - | remarks | - | null as remarks | null |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |
| 14 | derived | - | time_zone_id | - | COALESCE( utc_tz.utc_time_zone_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS time_zone_id | COALESCE( utc_tz.utc_time_zone_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 15 | derived | - | is_confirmed | - | false AS is_confirmed | false |
| 16 | derived | - | sign_on_time_reference | - | 0 as sign_on_time_reference | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
