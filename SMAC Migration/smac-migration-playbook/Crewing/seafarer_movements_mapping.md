# Table Mapping: seafarer_movements → seafarer_movements

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

- Preserves legacy UUID from source id column
- vessel_id mapping queries from smac_master_migration.migration.table_mappings via dblink
- seafarer_uuid is uuid in source, may need mapping if seafarers table uses different UUID
- Migrates dg_sign_on_sign_offs to seafarer_movements table. Preserves legacy UUID from source id column as target id. Maps seafarer_uuid (uuid) to seafarer_id (uuid) - uses mapping table if available, otherwise uses seafarer_uuid directly. Maps vessel_id (bigint) to uuid via migration.table_mappings from smac_master_migration (generates UUID if mapping not found - NOT NULL constraint). Maps contract_id (bigint) to seafarer_assignment_id (uuid) via migration.table_mappings from smac_crewing_migration (generates UUID if mapping not found - NOT NULL constraint, may need manual update). Maps dg_sign_on_date to sign_on_date, dg_sign_off_date to sign_off_date. Maps remarks to sign_on_notes. Sets defaults for new required fields: sign_on_verified (false), sign_off_verified (false), reminder_attempts (0), reminder_status ('Pending'), status (0 - Active), progress_status (gen_random_uuid()). Stores dg_initiated_date, dg_completed_date, dg_type, dg_status, file_attachment_ids in audit_info for reference.

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
| 1 | derived | - | id | - | DISTINCT ON (resolved_id) resolved_id as id | DISTINCT ON (resolved_id) resolved_id |
| 2 | derived | - | seafarer_id | - | COALESCE(joined_data.mapped_seafarer_id, joined_data.seafarer_uuid) as seafarer_id | COALESCE(joined_data.mapped_seafarer_id, joined_data.seafarer_uuid) |
| 3 | derived | - | vessel_id | - | COALESCE(joined_data.mapped_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_id | COALESCE(joined_data.mapped_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | port_of_registry_id | - | COALESCE(joined_data.port_of_registry_id, '00000000-0000-0000-0000-000000000000'::uuid) as port_of_registry_id | COALESCE(joined_data.port_of_registry_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | seafarer_assignment_id | - | COALESCE(joined_data.mapped_assignment_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_assignment_id | COALESCE(joined_data.mapped_assignment_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | derived | - | sign_on_date | - | CASE WHEN UPPER(TRIM(COALESCE(joined_data.dg_type, ''))) = 'SIGNON' THEN joined_data.sea_experience_ | CASE WHEN UPPER(TRIM(COALESCE(joined_data.dg_type, ''))) = 'SIGNON' THEN joined_data.sea_experience_ |
| 7 | - | - | sign_off_date | - | See source script | See source script |
| 8 | - | - | sign_on_status | - | See source script | See source script |
| 9 | - | - | sign_off_status | - | See source script | See source script |
| 10 | - | - | sign_on_verified | - | See source script | See source script |
| 11 | - | - | sign_off_verified | - | See source script | See source script |
| 12 | - | - | sign_on_approval_status | - | See source script | See source script |
| 13 | - | - | sign_off_approval_status | - | See source script | See source script |
| 14 | - | - | immigration_status | - | See source script | See source script |
| 15 | - | - | customs_clearance_status | - | See source script | See source script |
| 16 | - | - | sign_on_notes | - | See source script | See source script |
| 17 | - | - | sign_off_notes | - | See source script | See source script |
| 18 | - | - | country_specific_requirements | - | See source script | See source script |
| 19 | - | - | government_body_id | - | See source script | See source script |
| 20 | - | - | progress_status | - | See source script | See source script |
| 21 | - | - | next_reminder_due | - | See source script | See source script |
| 22 | - | - | reminder_attempts | - | See source script | See source script |
| 23 | - | - | last_reminder_sent_at | - | See source script | See source script |
| 24 | - | - | reminder_status | - | See source script | See source script |
| 25 | - | - | status | - | See source script | See source script |
| 26 | - | - | tenant_id | - | See source script | See source script |
| 27 | - | - | created_at | - | See source script | See source script |
| 28 | - | - | updated_at | - | See source script | See source script |
| 29 | - | - | archived_at | - | See source script | See source script |
| 30 | - | - | deleted_at | - | See source script | See source script |
| 31 | - | - | audit_info | - | See source script | See source script |
| 32 | - | - | sign_off_submitted_date | - | See source script | See source script |
| 33 | - | - | sign_on_submitted_date | - | See source script | See source script |
| 34 | - | - | sign_off_submitted_by | - | See source script | See source script |
| 35 | - | - | sign_on_submitted_by | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
