# Table Mapping: supernumerary_complements → supernumerary_assignments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: supernumerary_complements
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: supernumerary_assignments
- **Source Script**: `04-migration-scripts/crewing/supernumerary_assignments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.supernumerary_complements`
- **New Path**: `smac_crewing_migration.public.supernumerary_assignments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Supernumerary Assignments (`supernumerary_complements` → `supernumerary_assignments`)

## Migration Notes

- Source `supernumerary_complements` → `public.supernumerary_assignments`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`; duplicate UUID check
- `vessel_id` mapped via `vessel_id_mapping` (INNER JOIN — unmapped vessels excluded)
- `vessel_revision_id` from active revision lookup; `current_relief_id` → `seafarer_assignment_id`
- Port IDs extracted from JSONB `actual_sign_on_port` / `actual_sign_off_port` → `id` field
- `status` integer derived from `deleted_at` + `status` text (Case 2 — `deleted_at` takes precedence)
- `audit_info` copied directly from source (not rebuilt)
- Requires vessels, family members, assignments, nationalities, ports migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.supernumerary_assignments` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`, `ranks`, `positions`, `nationalities`, `ports`, `workflow_status`, `time_zones`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 8

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |
| `family_details_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `assignment_id_mapping` | FK lookup | `legacy_relief_id`, `assignment_id` | `migration.table_mappings` (see SQL) | - |
| `nationality_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_id_mapping` | Assignme | `workflow_status_id` | - | `smac_master_migration` |
| `time_zone_id_mapping` | FK lookup | `time_zone_id` | - | `smac_master_migration` |

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### `family_details_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_family_members

```sql
CREATE TEMP TABLE family_details_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_family_members'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `assignment_id_mapping`

- **Output columns**: legacy_relief_id, assignment_id
- **migration.table_mappings**: target_table=seafarer_vessel_assignments

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `nationality_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `workflow_status_id_mapping`

- **Purpose**: Assignme
- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `time_zone_id_mapping`

- **Output columns**: time_zone_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE time_zone_id_mapping AS
SELECT id AS time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE code = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | `vessel_id_mapping` (INNER JOIN) | Required |
| 3 | — | — | `vessel_revision_id` | uuid | Active revision or nil UUID | |
| 4 | `seafarer_id` | uuid | `seafarer_id` | uuid | Direct copy | |
| 5 | `family_details_id` | bigint | `family_details_id` | uuid | `family_details_id_mapping` | Optional |
| 6 | — | — | `family_details_info` | text | `NULL` | |
| 7 | `current_relief_id` | bigint | `seafarer_assignment_id` | uuid | `assignment_id_mapping` | |
| 8 | `supernumerary_rank_id` | uuid | `rank_id` | uuid | Direct copy | |
| 9 | `supernumerary_position` | uuid | `position_id` | uuid | Direct copy | |
| 10 | `nationality_id` | bigint | `nationality_id` | uuid | `nationality_id_mapping` | |
| 11 | `complement_code` | character varying | `supernumerary_code` | text | `TRIM(complement_code)` | |
| 12 | `first_name` | text | `first_name` | text | `TRIM(first_name)` | |
| 13 | `last_name` | text | `last_name` | text | `TRIM(last_name)` | |
| 14 | `date_of_birth` | date | `dob` | timestamp without time zone | Cast to timestamp | |
| 15 | `status` | text | `on_board_status` | text | `COALESCE(TRIM(status), 'Active')` | |
| 16 | `actual_sign_on_date` | timestamp with time zone | `sign_on_timestamp_utc` | timestamp without time zone | Cast | Same value for local |
| 17 | `actual_sign_on_date` | timestamp with time zone | `sign_on_timestamp_local` | timestamp without time zone | Cast | |
| 18 | `actual_sign_on_port` | jsonb | `sign_on_port_id` | uuid | Port map from JSON `id`; nil UUID fallback | |
| 19 | — | — | `sign_on_time_zone_id` | uuid | UTC lookup; nil UUID fallback | |
| 20 | `sign_on_initiated_info` | jsonb | `sign_on_remarks` | text | `::text` | |
| 21 | `sign_on_confirmed_by` | jsonb | `sign_on_confirmed_by` | uuid | Extract `id` from JSON | |
| 22 | `sign_on_confirmed_by` | jsonb | `sign_on_confirmed_on` | timestamp without time zone | `NOW()` when JSON id present | Derived |
| 23 | `actual_sign_off_date` | timestamp with time zone | `has_sign_off_info` | boolean | `IS NOT NULL` | |
| 24 | `planned_sign_off_date_info` | jsonb | `expected_sign_off_info` | text | `::text` | |
| 25 | `actual_sign_off_date` | timestamp with time zone | `sign_off_timestamp_utc` | timestamp without time zone | Cast | |
| 26 | `actual_sign_off_date` | timestamp with time zone | `sign_off_timestamp_local` | timestamp without time zone | Cast | |
| 27 | `actual_sign_off_port` | jsonb | `sign_off_port_id` | uuid | Port map from JSON `id` | Nullable |
| 28 | — | — | `sign_off_time_zone_id` | uuid | UTC lookup | |
| 29 | — | — | `sign_off_remarks` | text | `NULL` | |
| 30 | `sign_off_confirmed_by` | jsonb | `sign_off_confirmed_by` | uuid | Extract `id` from JSON | |
| 31 | `sign_off_confirmed_by` | jsonb | `sign_off_confirmed_on` | timestamp without time zone | `NOW()` when JSON id present | Derived |
| 32 | `actual_duration_in_days` | bigint | `tenure` | text | `::text` | |
| 33 | — | — | `workflow_status_id` | uuid | APPROVED lookup or nil UUID | |
| 34 | — | — | `is_verified` | boolean | Hardcoded `false` | |
| 35 | — | — | `verified_at` | timestamp without time zone | `NULL` | |
| 36 | — | — | `verified_by_id` | uuid | `NULL` | |
| 37 | — | — | `verification_notes` | text | `NULL` | |
| 38 | `deleted_at`, `status` | timestamp/text | `status` | integer | `deleted_at` → Deleted (3); else map status string | Case 2 |
| 39 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 40 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 41 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 42 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 43 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 44 | `audit_info` | jsonb | `audit_info` | jsonb | Direct copy | Not rebuilt |
| 45 | — | — | `remarks` | text | `NULL` | |

**SMAC columns not migrated:** `family_details_info`, `sign_off_remarks`, `is_verified`, `verified_at`, `verified_by_id`, `verification_notes`, `archived_at`, `remarks` — NULL or defaults.

**SAC columns not migrated:** Any columns on `supernumerary_complements` not in dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `nationalities`
- `ports`
- `positions`
- `ranks`
- `time_zones`
- `vessel_revisions`
- `vessels`
- `workflow_status`

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
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 2. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 3. Family Details ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_family_members'`

```sql
CREATE TEMP TABLE family_details_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_family_members'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 4. Assignment ID Mapping
**Output columns**: `legacy_relief_id, assignment_id`
**migration.table_mappings**: `target_table='seafarer_vessel_assignments'`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 5. Nationality ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 6. Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'' AND target_db = ''smac_master_migration'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 7. Workflow Status ID Mapping
**Purpose**: Assignme
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 8. Time Zone ID Mapping
**Output columns**: `time_zone_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE time_zone_id_mapping AS
SELECT id AS time_zone_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.time_zones WHERE code = ''UTC'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/supernumerary_assignments_migration.sql`

## Validation

- Run `05-validation/crewing/supernumerary_assignments_validation.sql` if available
- Run `06-rollback/crewing/supernumerary_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
