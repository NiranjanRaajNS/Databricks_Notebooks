# Table Mapping: appraisal_debrief → seafarer_debriefs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_debrief
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_debriefs, seafarer_debrief_levels, seafarer_debrief_level_members
- **Source Script**: `04-migration-scripts/crewing/seafarer_debriefs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_debrief`
- **New Path**: `smac_crewing_migration.shore.seafarer_debriefs, seafarer_debrief_levels, seafarer_debrief_level_members`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debriefs (`appraisal_debrief` → `seafarer_debriefs`)

## Migration Notes

- Source: `synergy_seafarer.public.appraisal_debrief` with non-empty `feedback` JSONB array only
- SAC `id` (uuid) preserved directly as target `id` (no `resolve_target_id`)
- `seafarer_uuid` copied directly to `seafarer_id`; `vessel_uuid` → `vessel_id` via mappings; `vessel_category_id` → `vessel_type_id`
- `debrief_status` mapped to `current_stage` (e.g. debriefing_initiated → DebriefInitiated); `workflow_status` from first feedback element `status`
- `attachments` (text[]) converted to jsonb; `from_date`/`to_date` → `sign_on_date`/`sign_off_date`
- `closed_at` set when debrief_status indicates closed; `initiated_by`/`closed_by` NULL (no user mapping)
- `vessel_revision_id` from active vessel revision lookup; requires `seafarers`, `vessels`, `vessel_types`

## Special Considerations

- Script truncates target table(s) before insert (full reload): `shore.seafarer_debrief_level_members`, `shore.seafarer_debrief_levels`, `shore.seafarer_debriefs`.
- Orchestration dependencies: `seafarers`, `vessels`, `vessel_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `legacy_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `debrief_vessel_lookup` | FK lookup | `legacy_vessel_identifier`, `legacy_vessel_id` | - | `synergy_vessel` |
| `vessel_revision_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |
| `vessel_type_id_mapping` | FK lookup | `legacy_category_id`, `new_type_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarer_uuid_mapping`

- **Output columns**: legacy_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT
    source_id::uuid as legacy_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

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

### `debrief_vessel_lookup`

- **Output columns**: legacy_vessel_identifier, legacy_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE debrief_vessel_lookup AS
SELECT DISTINCT
    vd.identifier AS legacy_vessel_identifier,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id FROM public.vessel_details WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

### `vessel_revision_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN (
    SELECT new_id AS vessel_id FROM vessel_id_mapping
) AS all_vessels ON all_vessels.vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### `vessel_type_id_mapping`

- **Output columns**: legacy_category_id, new_type_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_category_id,
    target_id as new_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'''
) AS t(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | Direct copy | Preserves legacy UUID |
| 2 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Direct copy | FK to `seafarers.id` (preserved UUID) |
| 3 | — | — | `seafarer_assignment_id` | uuid | `NULL` | No SAC equivalent |
| 4 | — | — | `appraisal_id` | uuid | `NULL` | No SAC equivalent |
| 5 | `debrief_reason_id` | uuid | `reason_id` | uuid | Direct copy | FK to debrief reason master |
| 6 | `other_debrief_reason` | text | `reason_text` | text | `TRIM(other_debrief_reason)` | Free-text reason |
| 7 | `vessel_uuid` (derived) | uuid | `vessel_id` | uuid | Map via `vessel_id_mapping` / `debrief_vessel_lookup` | Lookup: `vessels` (`smac_master_migration`) |
| 8 | `vessel_category_id` | bigint | `vessel_type_id` | uuid | Map via `vessel_type_id_mapping`; nil UUID fallback | Lookup: `vessel_types` mappings |
| 9 | `from_date` | timestamp | `sign_on_date` | date | `from_date::date` | Column rename |
| 10 | `to_date` | timestamp | `sign_off_date` | date | `to_date::date` | Column rename |
| 11 | — | — | `appraisal_reports_available` | boolean | Hardcoded `false` | Not in SAC |
| 12 | `attachments` | text[] | `attachments` | jsonb | `to_jsonb(attachments)` when array non-empty | Type change text[] → jsonb |
| 13 | `debrief_status` | text | `current_stage` | text | Map SAC status values to SMAC stage names (e.g. debriefing_initiated → DebriefInitiated) | Business logic mapping |
| 14 | `feedback` → `[0].status` | jsonb | `workflow_status` | text | First feedback array element `status` | Extracted from JSONB |
| 15 | — | — | `initiated_by` | uuid | `NULL` | No user mapping available |
| 16 | `initiated_date`, `created_at` | timestamp | `initiated_at` | timestamp | `COALESCE(initiated_date, created_at)` | Prefer initiated_date |
| 17 | — | — | `closed_by` | uuid | `NULL` | No user mapping available |
| 18 | `debrief_status`, `updated_at` | text, timestamp | `closed_at` | timestamp | `updated_at` when status is closed/completed | Conditional on debrief_status |
| 19 | — | — | `status` | text | Hardcoded `'Active'` | All migrated records Active |
| 20 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 21 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 22 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 23 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 24 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 25 | `created_by_id`, `deleted_by`, `updated_by_id`, `id` | mixed | `audit_info` | jsonb | Standard SMAC structure with `legacy_id` | Includes `legacy_id` in audit_info |
| 26 | `vessel_uuid` (derived) | uuid | `vessel_revision_id` | uuid | `COALESCE(vessel_revision_mapping.active_revision_id, nil UUID)` | Active vessel revision lookup |

**SMAC columns not migrated:** `seafarer_assignment_id`, `appraisal_id`, `initiated_by`, `closed_by`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** `rank_id`, `mark_for_deactivations`, `is_manual`, `training_needs` (used in levels, not debriefs row), `created_by_name`, `updated_by_name` — not mapped to separate SMAC columns.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `vessel_types`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `legacy_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT
    source_id::uuid as legacy_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### 2. Vessel ID Mapping
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

### 3. Debrief Vessel ID Mapping
**Output columns**: `legacy_vessel_identifier, legacy_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE debrief_vessel_lookup AS
SELECT DISTINCT
    vd.identifier AS legacy_vessel_identifier,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id FROM public.vessel_details WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

### 4. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN (
    SELECT new_id AS vessel_id FROM vessel_id_mapping
) AS all_vessels ON all_vessels.vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 5. Vessel Type ID Mapping
**Output columns**: `legacy_category_id, new_type_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_category_id,
    target_id as new_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'''
) AS t(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_debriefs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debriefs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debriefs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
