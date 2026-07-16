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

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Batch processing by SAC `id` range for large datasets
- Filter: `is_manual = true` OR (`rank_id IN (13, 18, 17)` AND `is_manual = false`)
- UUID dedup: prefer records with attachments, then highest `id`
- `seafarer_assignment_id` from `contract_id` via `contract_to_assignment_id_mapping`
- `average_score` averaged from `appraisal_rating` JSONB array `Rating` values
- `workflow_status_id` mapped from SAC `status` text to `workflow_status` codes
- Only migrates rows where `seafarer_id` mapping exists
- Pre-migration duplicate UUID check on SAC `uuid` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_appraisals` before insert (full table reload)
- `DISTINCT ON (id)` with UUID deduplication logic
- Orchestration dependencies: `seafarers`, `seafarer_attachments`, `seafarer_contracts`, `vessels`, `ranks`, `appraisal_types`, `categories`

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
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; empty GUID fallback | Required — unmapped seafarers excluded |
| 3 | `contract_id` | bigint | `seafarer_assignment_id` | uuid | Map via `contract_to_assignment_id_mapping`; empty GUID fallback | Legacy contract → `seafarer_vessel_assignments.id` |
| 4 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping`; empty GUID fallback | Lookup: `migration.table_mappings` (`vessels`) |
| 5 | `vessel_category_id` | bigint | `vessel_type_id` | uuid | Map via `vessel_category_id_mapping` | Lookup: `migration.table_mappings` (`categories`) |
| 6 | `rank_id` | bigint | `rank_id` | uuid | Map via `rank_id_mapping`; empty GUID fallback | Lookup: `migration.table_mappings` (`ranks`) |
| 7 | `appraisal_type_id` | bigint | `appraisal_type_id` | uuid | Map via `appraisal_type_id_mapping`; empty GUID fallback | Lookup: `migration.table_mappings` (`appraisal_types`) |
| 8 | `is_manual` | boolean | `appraisal_mode` | text | `true` → `'Manual'`; else `'Digital'` | Boolean to text enum |
| 9 | `from_date` | timestamp without time zone | `period_from` | date | Cast to date; `CURRENT_DATE` when NULL | NOT NULL in SMAC |
| 10 | `to_date` | timestamp without time zone | `period_to` | date | Cast to date; `CURRENT_DATE` when NULL | NOT NULL in SMAC |
| 11 | `appraisal_rating` | jsonb | `average_score` | numeric | `AVG(Rating)` from JSONB array elements | Extracts `Rating` field from each array item |
| 12 | `status` | text | `appraisal_status` | text | INITIATED→Draft; CLOSED→closed; else UnderReview | Display status separate from workflow |
| 13 | `status` | text | `workflow_status_id` | uuid | Map SAC status to `workflow_status` codes via `workflow_status_mapping` | e.g. SUBMITTED→AppraisalSubmitted, CLOSED→AppraisalClosed |
| 14 | `comment` | text | `remarks` | text | `TRIM(COALESCE(comment, ''))` | SAC `comment` renamed to `remarks` |
| 15 | `suitable_for_promotion` | boolean | `suitable_for_promotion` | text | `true`→`'true'`; `false`→`'false'`; else NULL | Boolean to text conversion |
| 16 | `created_by_id` | text | `initiated_by` | uuid | Cast to UUID when valid UUID format; else NULL | May need user mapping in future |
| 17 | `entered_by` | text | `submitted_by` | uuid | Cast to UUID when valid UUID format; else NULL | SAC `entered_by` → SMAC `submitted_by` |
| 18 | `created_at` | timestamp without time zone | `initiated_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | SAC `created_at` also maps to `created_at` |
| 19 | `entered_date` | timestamp without time zone | `submitted_at` | timestamp without time zone | Direct copy | SAC `entered_date` renamed to `submitted_at` |
| 20 | — | — | `closed_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 21 | `attachments` | text[] | `attachments` | jsonb | Map each element via `attachment_id_mapping`; preserve unmapped as text | Lookup: `migration.table_mappings` (`seafarer_attachments`) |
| 22 | — | — | `status` | text | Hardcoded `'active'` | SMAC record status string; not SAC `status` column |
| 23 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 24 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 25 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 26 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 27 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 28 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names in `notes` | No `legacy_id` (uuid preserved as `id`) |
| 29 | `vessel_revisions` (active) | — | `vessel_revision_id` | uuid | Map via `vessel_revision_id_mapping`; empty GUID fallback | Active revision for mapped vessel |
| 30 | `debrief_reason_id` | uuid | `debrief_reason_id` | uuid | Direct copy | UUID preserved |
| 31 | `disciplinary_action_required` | boolean | `disciplinary_action_required` | boolean | Direct copy | Direct mapping |
| 32 | `disciplinary_reason_id` | uuid | `disciplinary_reason_id` | uuid | Direct copy | UUID preserved |
| 33 | `disciplinary_reason_other_text` | text | `disciplinary_reason_other_text` | text | Direct copy | Direct mapping |
| 34 | `other_debrief_reason` | text | `other_debrief_reason` | text | Direct copy | Direct mapping |
| 35 | `debriefing_at_shore` | boolean | `debriefing_required` | boolean | Direct copy | SAC `debriefing_at_shore` renamed to `debriefing_required` |

**SAC columns not migrated:** `comment_by`, `feedback` — present in dblink SELECT but not inserted into SMAC.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `appraisal_types`
- `public.seafarer_attachments`
- `public.seafarers`
- `ranks`
- `seafarers`
- `vessels`

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
