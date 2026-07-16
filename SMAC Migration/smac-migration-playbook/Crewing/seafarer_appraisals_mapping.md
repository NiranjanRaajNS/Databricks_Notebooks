# Table Mapping: appraisals → seafarer_appraisals

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisals
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisals
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisals_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisals`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisals`

## Business Key

- **Business Key**: `uuid`
- **Source (orchestration)**: Seafarer Appraisals (`appraisals` → `seafarer_appraisals`)

## Migration Notes

- Migrates appraisals to seafarer_appraisals table. Preserves legacy UUID when available. Maps seafarer_id (bigint) to uuid via smac_crewing_migration.migration.table_mappings. Maps rank_id, vessel_id, appraisal_type_id (bigint) to uuid via smac_master_migration.migration.table_mappings. Derives vessel_type_id from vessels table. Converts data types: boolean→text, array→jsonb, timestamp→date. Extracts average_score from appraisal_rating JSONB. Sets seafarer_assignment_id to NULL (not derived). Only migrates records where seafarer_id can be mapped.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_appraisals` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `ranks`, `appraisal_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 9

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_id_mapping` | FK lookup | `vessel_legacy_id`, `vessel_id_target` | `migration.table_mappings` (see SQL) | `synergy_seafarer` |
| `appraisal_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_category_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `attachment_id_mapping` | FK lookup | `legacy_id`, `new_uuid` | `migration.table_mappings` (see SQL) | - |
| `contract_to_assignment_id_mapping` | Create vessel_id lookup mapping | `legacy_contract_id`, `assignment_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_revision_id_mapping` | FK lookup | `vessel_id`, `vessel_revision_id` | - | `smac_master_migration` |
| `workflow_status_mapping` | Create appraisal_type_id lookup mapping (from smac_master_migration) | `workflow_status_id`, `status_name_normalized`, `workflow_status_code` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_id_mapping`

- **Output columns**: vessel_legacy_id, vessel_id_target
- **migration.table_mappings**: target_table=
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    v.id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.appraisals
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS a(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS v(id bigint)
    ON v.id = a.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'''
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = v.id::text;
```

### `appraisal_type_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_type_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''appraisal_types'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_category_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `attachment_id_mapping`

- **Output columns**: legacy_id, new_uuid
- **migration.table_mappings**: target_table=seafarer_attachments

```sql
CREATE TEMP TABLE attachment_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint as legacy_id,
    target_id as new_uuid
FROM migration.table_mappings
WHERE target_table = 'seafarer_attachments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id DESC;
```

### `contract_to_assignment_id_mapping`

- **Purpose**: Create vessel_id lookup mapping
- **Output columns**: legacy_contract_id, assignment_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_to_assignment_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint AS legacy_contract_id,
    sva.id AS assignment_id
FROM migration.table_mappings tm
INNER JOIN public.seafarer_vessel_assignments sva ON sva.contract_id = tm.target_id
WHERE tm.target_table = 'seafarer_contracts'
  AND tm.target_db = current_database()
  AND tm.source_id ~ '^[0-9]+$'
ORDER BY tm.source_id::bigint, sva.created_at DESC NULLS LAST, sva.id DESC;
```

### `vessel_revision_id_mapping`

- **Output columns**: vessel_id, vessel_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (v_map.vessel_id_target)
    v_map.vessel_id_target as vessel_id,
    vr.id as vessel_revision_id
FROM vessel_id_mapping v_map
INNER JOIN dblink('smac_master_migration',
    'SELECT id, vessel_id FROM vessel.vessel_revisions WHERE status = 0 ORDER BY id DESC'
) AS vr(id uuid, vessel_id uuid)
    ON vr.vessel_id = v_map.vessel_id_target
ORDER BY v_map.vessel_id_target, vr.id DESC;
```

### `workflow_status_mapping`

- **Purpose**: Create appraisal_type_id lookup mapping (from smac_master_migration)
- **Output columns**: workflow_status_id, status_name_normalized, workflow_status_code
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_mapping AS
SELECT
    t.id as workflow_status_id,
    UPPER(TRIM(t.name)) as status_name_normalized,
    t.code as workflow_status_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM public.workflow_status'
) AS t(id uuid, name varchar, code varchar);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'appraisals'::VARCHAR(100), legacy_data.id::text, current_dat... |
| 2 | derived | - | seafarer_id | - | COALESCE( s_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( s_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | seafarer_assignment_id | - | COALESCE( ca_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_assignment_id | COALESCE( ca_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | derived | - | vessel_id | - | COALESCE(v_map.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_id | COALESCE(v_map.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | vessel_type_id | - | COALESCE(vc_map.new_id, NULL) as vessel_type_id | COALESCE(vc_map.new_id, NULL) |
| 6 | derived | - | rank_id | - | COALESCE(r_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as rank_id | COALESCE(r_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 7 | derived | - | appraisal_type_id | - | COALESCE(at_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as appraisal_type_id | COALESCE(at_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 8 | derived | - | appraisal_mode | - | CASE WHEN is_manual = true THEN 'Manual' ELSE 'Digital' END as appraisal_mode | CASE WHEN is_manual = true THEN 'Manual' ELSE 'Digital' END |
| 9 | derived | - | period_from | - | COALESCE(from_date::date, CURRENT_DATE) as period_ | COALESCE(from_date::date, CURRENT_DATE) as period_ |
| 10 | - | - | period_to | - | See source script | See source script |
| 11 | - | - | average_score | - | See source script | See source script |
| 12 | - | - | appraisal_status | - | See source script | See source script |
| 13 | - | - | workflow_status_id | - | See source script | See source script |
| 14 | - | - | remarks | - | See source script | See source script |
| 15 | - | - | suitable_for_promotion | - | See source script | See source script |
| 16 | - | - | initiated_by | - | See source script | See source script |
| 17 | - | - | submitted_by | - | See source script | See source script |
| 18 | - | - | initiated_at | - | See source script | See source script |
| 19 | - | - | submitted_at | - | See source script | See source script |
| 20 | - | - | closed_at | - | See source script | See source script |
| 21 | - | - | attachments | - | See source script | See source script |
| 22 | - | - | status | - | See source script | See source script |
| 23 | - | - | tenant_id | - | See source script | See source script |
| 24 | - | - | created_at | - | See source script | See source script |
| 25 | - | - | updated_at | - | See source script | See source script |
| 26 | - | - | archived_at | - | See source script | See source script |
| 27 | - | - | deleted_at | - | See source script | See source script |
| 28 | - | - | audit_info | - | See source script | See source script |
| 29 | - | - | vessel_revision_id | - | See source script | See source script |
| 30 | - | - | debrief_reason_id | - | See source script | See source script |
| 31 | - | - | disciplinary_action_required | - | See source script | See source script |
| 32 | - | - | disciplinary_reason_id | - | See source script | See source script |
| 33 | - | - | disciplinary_reason_other_text | - | See source script | See source script |
| 34 | - | - | other_debrief_reason | - | See source script | See source script |
| 35 | - | - | debriefing_required | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_attachments`
- `public.seafarers`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Rank ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 3. Vessel ID Mapping
**Output columns**: `vessel_legacy_id, vessel_id_target`
**migration.table_mappings**: see SQL below
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    v.id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.appraisals
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS a(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS v(id bigint)
    ON v.id = a.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'''
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = v.id::text;
```

### 4. Appraisal Type ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_type_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''appraisal_types'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 5. Vessel Category ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 6. Attachment ID Mapping
**Output columns**: `legacy_id, new_uuid`
**migration.table_mappings**: `target_table='seafarer_attachments'`

```sql
CREATE TEMP TABLE attachment_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint as legacy_id,
    target_id as new_uuid
FROM migration.table_mappings
WHERE target_table = 'seafarer_attachments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$'
ORDER BY source_id::bigint, target_id DESC;
```

### 7. Contract To Assignment ID Mapping
**Purpose**: Create vessel_id lookup mapping
**Output columns**: `legacy_contract_id, assignment_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_to_assignment_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint AS legacy_contract_id,
    sva.id AS assignment_id
FROM migration.table_mappings tm
INNER JOIN public.seafarer_vessel_assignments sva ON sva.contract_id = tm.target_id
WHERE tm.target_table = 'seafarer_contracts'
  AND tm.target_db = current_database()
  AND tm.source_id ~ '^[0-9]+$'
ORDER BY tm.source_id::bigint, sva.created_at DESC NULLS LAST, sva.id DESC;
```

### 8. Vessel Revision ID Mapping
**Output columns**: `vessel_id, vessel_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (v_map.vessel_id_target)
    v_map.vessel_id_target as vessel_id,
    vr.id as vessel_revision_id
FROM vessel_id_mapping v_map
INNER JOIN dblink('smac_master_migration',
    'SELECT id, vessel_id FROM vessel.vessel_revisions WHERE status = 0 ORDER BY id DESC'
) AS vr(id uuid, vessel_id uuid)
    ON vr.vessel_id = v_map.vessel_id_target
ORDER BY v_map.vessel_id_target, vr.id DESC;
```

### 9. Workflow Status ID Mapping
**Purpose**: Create appraisal_type_id lookup mapping (from smac_master_migration)
**Output columns**: `workflow_status_id, status_name_normalized, workflow_status_code`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_mapping AS
SELECT
    t.id as workflow_status_id,
    UPPER(TRIM(t.name)) as status_name_normalized,
    t.code as workflow_status_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM public.workflow_status'
) AS t(id uuid, name varchar, code varchar);
```

Full migration context: `04-migration-scripts/crewing/seafarer_appraisals_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_appraisals_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisals_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
