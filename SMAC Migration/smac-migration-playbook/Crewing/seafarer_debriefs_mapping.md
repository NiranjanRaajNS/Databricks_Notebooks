# Table Mapping: appraisal_debrief → seafarer_debriefs, seafarer_debrief_levels, seafarer_debrief_level_members

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

- One source record splits into:
- Migrates appraisal_debrief to seafarer_debriefs table. Preserves legacy UUID id directly. Maps seafarer_uuid (uuid) to seafarer_id (uuid) via migration.table_mappings. Maps vessel_uuid (uuid) to vessel_id (uuid) via migration.table_mappings from smac_master_migration. Maps vessel_category_id (bigint) to vessel_type_id (uuid) via migration.table_mappings from smac_master_migration. Converts attachments (text[]) to jsonb. Maps debrief_status to both current_stage and status. Conditional mapping for closed_by/closed_at based on debrief_status. Requires seafarers, vessels, and vessel_types tables to be migrated first.

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
| 1 | id | - | id | - | legacy_data.id as id | legacy_data.id |
| 2 | seafarer_uuid | - | seafarer_id | - | legacy_data.seafarer_uuid as seafarer_id | legacy_data.seafarer_uuid |
| 3 | derived | - | seafarer_assignment_id | - | NULL as seafarer_assignment_id | NULL |
| 4 | derived | - | appraisal_id | - | NULL as appraisal_id | NULL |
| 5 | debrief_reason_id | - | reason_id | - | legacy_data.debrief_reason_id as reason_id | legacy_data.debrief_reason_id |
| 6 | other_debrief_reason | - | reason_text | - | TRIM(legacy_data.other_debrief_reason) as reason_text | TRIM(legacy_data.other_debrief_reason) |
| 7 | derived | - | vessel_id | - | vessel_map.new_id as vessel_id | vessel_map.new_id |
| 8 | derived | - | vessel_type_id | - | COALESCE(vessel_type_map.new_type_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_type_id | COALESCE(vessel_type_map.new_type_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 9 | derived | - | sign_on_date | - | legacy_data. | legacy_data. |
| 10 | - | - | sign_off_date | - | See source script | See source script |
| 11 | - | - | appraisal_reports_available | - | See source script | See source script |
| 12 | - | - | attachments | - | See source script | See source script |
| 13 | - | - | current_stage | - | See source script | See source script |
| 14 | - | - | workflow_status | - | See source script | See source script |
| 15 | - | - | initiated_by | - | See source script | See source script |
| 16 | - | - | initiated_at | - | See source script | See source script |
| 17 | - | - | closed_by | - | See source script | See source script |
| 18 | - | - | closed_at | - | See source script | See source script |
| 19 | - | - | status | - | See source script | See source script |
| 20 | - | - | tenant_id | - | See source script | See source script |
| 21 | - | - | created_at | - | See source script | See source script |
| 22 | - | - | updated_at | - | See source script | See source script |
| 23 | - | - | archived_at | - | See source script | See source script |
| 24 | - | - | deleted_at | - | See source script | See source script |
| 25 | - | - | audit_info | - | See source script | See source script |
| 26 | - | - | vessel_revision_id | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
