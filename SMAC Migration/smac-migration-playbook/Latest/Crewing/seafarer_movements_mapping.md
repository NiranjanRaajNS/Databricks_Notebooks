# Table Mapping: dg_sign_on_sign_offs → seafarer_movements

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_movements
- **Source Script**: `04-migration-scripts/crewing/seafarer_movements_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: DG Sign On Sign Offs (`dg_sign_on_sign_offs` → `seafarer_movements`)

## Migration Notes

- Source: SAC `dg_sign_on_sign_offs` joined with `sea_experiences`, `relief_summary`, vessel revisions, DG notifications
- SAC `id` (uuid) preserved as SMAC `id` via `resolved_id` / `DISTINCT ON (resolved_id)`
- `seafarer_id`: mapped seafarer UUID or direct `seafarer_uuid` fallback
- `vessel_id`, `seafarer_assignment_id`, `port_of_registry_id` via lookup tables; nil UUID if unmapped
- Sign-on/off dates from `sea_experiences` when `dg_type` = SIGNON/SIGNOFF
- Sign-on/off status from `dg_status` mapped via `dg_statuses_id_mapping`
- `sign_on_notes` / `sign_off_notes` from `remarks` when dg_type matches
- `country_specific_requirements` ← `file_attachment_ids` JSONB
- `reminder_status` from DG notifications; default `'pending'`
- `status` (integer): `deleted_at IS NOT NULL` → 3 (Deleted), else 0 (Active)
- `audit_info`: standard SMAC structure (no `legacy_id` — uuid preserved as `id`)
- Requires `seafarers`, `vessels`, `seafarer_assignments` migrated first

## Special Considerations

- Maps seafarer_uuid, vessel_id, and contract_id via migration.table_mappings
- Script performs `TRUNCATE TABLE shore.seafarer_movements` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `seafarer_assignments`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessels_id_mapping` | FK lookup | `legacy_id::text`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_revision_id_mapping` | Create lookup tables for foreign key re | `new_vessel_id`, `active_revision_id`, `port_of_registry_id` | - | `smac_master_migration` |
| `dg_statuses_id_mapping` | FK lookup | `status_name`, `status_code`, `new_status_uuid` | - | `smac_master_migration` |
| `dg_notifications_mapping` | FK lookup | `DISTINCT ON (dg_id) dg_id`, `last_reminder_sent_at`, `reminder_status` | - | `synergy_seafarer` |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `vessels_id_mapping`

- **Output columns**: legacy_id::text, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    legacy_id::text,
    new_id
FROM dblink('smac_master_migration',
    'SELECT
        tm.source_id as legacy_id,
        tm.target_id as new_id
     FROM migration.table_mappings tm
     WHERE tm.target_table = ''vessels'' AND tm.target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### `vessel_revision_id_mapping`

- **Purpose**: Create lookup tables for foreign key re
- **Output columns**: new_vessel_id, active_revision_id, port_of_registry_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id,
    vr.registered_port_id AS port_of_registry_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at, registered_port_id
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp, registered_port_id uuid)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### `dg_statuses_id_mapping`

- **Output columns**: status_name, status_code, new_status_uuid
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE dg_statuses_id_mapping AS
SELECT
    ds.name::text as status_name,
    ds.code::text as status_code,
    ds.id as new_status_uuid
FROM dblink('smac_master_migration',
    'SELECT id, name, code
     FROM crewing.dg_statuses
     WHERE name IS NOT NULL'
) AS ds(id uuid, name text, code text)
WHERE ds.name IS NOT NULL;
```

### `dg_notifications_mapping`

- **Output columns**: DISTINCT ON (dg_id) dg_id, last_reminder_sent_at, reminder_status
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE dg_notifications_mapping AS
SELECT DISTINCT ON (dg_id)
    dg_id,
    notification_date as last_reminder_sent_at,
    notification_status as reminder_status
FROM dblink('synergy_seafarer',
    'SELECT dg_id, notification_date, notification_status FROM public.dg_sign_on_sign_off_notifications WHERE deleted_at IS NULL'
) AS n(dg_id uuid, notification_date timestamp, notification_status varchar)
ORDER BY dg_id, notification_date DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `resolved_id` — preserved SAC uuid | `DISTINCT ON (resolved_id)` |
| 2 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | `COALESCE(mapped_seafarer_id, seafarer_uuid)` | Map or direct UUID |
| 3 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` → `vessels` |
| 4 |- | uuid | `port_of_registry_id` | uuid | From active vessel revision; nil UUID fallback | Lookup: `vessel_revision_id_mapping` |
| 5 | `contract_id` | bigint | `seafarer_assignment_id` | uuid | Map via relief_summary → assignment; nil UUID fallback | Lookup: `table_mappings` → assignments |
| 6 | `dg_type`, `from_date` | text, date | `sign_on_date` | date | Set when `dg_type = SIGNON` from sea_experience `from_date` | Else NULL |
| 7 | `dg_type`, `to_date` | text, date | `sign_off_date` | date | Set when `dg_type = SIGNOFF` from sea_experience `to_date` | Else NULL |
| 8 | `dg_type`, `dg_status` | text | `sign_on_status` | uuid | DG status UUID when `dg_type = SIGNON` | Via `dg_statuses_id_mapping` |
| 9 | `dg_type`, `dg_status` | text | `sign_off_status` | uuid | DG status UUID when `dg_type = SIGNOFF` | Via `dg_statuses_id_mapping` |
| 10 | — | — | `sign_on_verified` | boolean | Hardcoded `false` | NOT NULL in SMAC |
| 11 | — | — | `sign_off_verified` | boolean | Hardcoded `false` | NOT NULL in SMAC |
| 12 | — | — | `sign_on_approval_status` | uuid | `NULL` | Not in SAC source |
| 13 | — | — | `sign_off_approval_status` | uuid | `NULL` | Not in SAC source |
| 14 | — | — | `immigration_status` | text | `NULL` | Not in SAC source |
| 15 | — | — | `customs_clearance_status` | text | `NULL` | Not in SAC source |
| 16 | `dg_type`, `remarks` | text | `sign_on_notes` | text | `TRIM(remarks)` when `dg_type = SIGNON` | Else NULL |
| 17 | `dg_type`, `remarks` | text | `sign_off_notes` | text | `TRIM(remarks)` when `dg_type = SIGNOFF` | Else NULL |
| 18 | `file_attachment_ids` | jsonb | `country_specific_requirements` | jsonb | `COALESCE(file_attachment_ids, '{}'::jsonb)` | SAC attachments preserved as JSONB |
| 19 | — | — | `government_body_id` | uuid | `NULL` | Not in SAC source |
| 20 | — | — | `progress_status` | uuid | Hardcoded nil UUID | NOT NULL placeholder |
| 21 | — | — | `next_reminder_due` | timestamp without time zone | `NULL` | Not in SAC source |
| 22 | — | — | `reminder_attempts` | integer | Hardcoded `0` | NOT NULL in SMAC |
| 23 | - | timestamp | `last_reminder_sent_at` | timestamp without time zone | From `dg_sign_on_sign_off_notifications` | Nullable |
| 24 | -| text | `reminder_status` | text | `COALESCE(reminder_status, 'pending')` | Default pending |
| 25 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → 3; else 0 | Case 1 — integer status |
| 26 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 27 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 28 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 29 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 30 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 31 | `created_by_id`, `deleted_by_id`, `updated_by_id` | text | `audit_info` | jsonb | Standard SMAC `jsonb_build_object()` | No `legacy_id` (uuid preserved as `id`) |
| 32 | `dg_type`, `dg_sign_off_date` | text, timestamp | `sign_off_submitted_date` | timestamp without time zone | `dg_sign_off_date` when `dg_type = SIGNOFF` | Else NULL |
| 33 | `dg_type`, `dg_sign_on_date` | text, timestamp | `sign_on_submitted_date` | timestamp without time zone | `dg_sign_on_date` when `dg_type = SIGNON` | Else NULL |
| 34 | `dg_type`, `created_by_id` | text | `sign_off_submitted_by` | uuid | Parse `created_by_id` as uuid when `dg_type = SIGNOFF` | Valid UUID format only |
| 35 | `dg_type`, `created_by_id` | text | `sign_on_submitted_by` | uuid | Parse `created_by_id` as uuid when `dg_type = SIGNON` | Valid UUID format only |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `dg_initiated_date`, `dg_completed_date` — referenced in comments only, not in target INSERT columns.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_assignments`
- `seafarers`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Vessels ID Mapping
**Output columns**: `legacy_id::text, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    legacy_id::text,
    new_id
FROM dblink('smac_master_migration',
    'SELECT
        tm.source_id as legacy_id,
        tm.target_id as new_id
     FROM migration.table_mappings tm
     WHERE tm.target_table = ''vessels'' AND tm.target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### 3. Vessel Revision ID Mapping
**Purpose**: Create lookup tables for foreign key re
**Output columns**: `new_vessel_id, active_revision_id, port_of_registry_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id,
    vr.registered_port_id AS port_of_registry_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at, registered_port_id
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp, registered_port_id uuid)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 4. Dg Statuses ID Mapping
**Output columns**: `status_name, status_code, new_status_uuid`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE dg_statuses_id_mapping AS
SELECT
    ds.name::text as status_name,
    ds.code::text as status_code,
    ds.id as new_status_uuid
FROM dblink('smac_master_migration',
    'SELECT id, name, code
     FROM crewing.dg_statuses
     WHERE name IS NOT NULL'
) AS ds(id uuid, name text, code text)
WHERE ds.name IS NOT NULL;
```

### 5. Dg Notifications ID Mapping
**Output columns**: `DISTINCT ON (dg_id) dg_id, last_reminder_sent_at, reminder_status`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE dg_notifications_mapping AS
SELECT DISTINCT ON (dg_id)
    dg_id,
    notification_date as last_reminder_sent_at,
    notification_status as reminder_status
FROM dblink('synergy_seafarer',
    'SELECT dg_id, notification_date, notification_status FROM public.dg_sign_on_sign_off_notifications WHERE deleted_at IS NULL'
) AS n(dg_id uuid, notification_date timestamp, notification_status varchar)
ORDER BY dg_id, notification_date DESC;
```

Full migration context: `04-migration-scripts/crewing/seafarer_movements_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_movements_validation.sql` if available
- Run `06-rollback/crewing/seafarer_movements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
