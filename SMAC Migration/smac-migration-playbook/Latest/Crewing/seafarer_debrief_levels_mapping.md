# Table Mapping: appraisal_debrief → seafarer_debrief_levels

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_debrief
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_debrief_levels
- **Source Script**: `04-migration-scripts/crewing/seafarer_debrief_levels_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_debrief`
- **New Path**: `smac_crewing_migration.shore.seafarer_debrief_levels`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debriefs (`appraisal_debrief` → `seafarer_debrief_levels`)

## Migration Notes

- Unpivot migration: one SMAC row per element in `appraisal_debrief.feedback` JSONB array
- Generates new UUID per level via `gen_random_uuid()`; `debrief_id` = preserved `appraisal_debrief.id`
- `templateName` mapped to `stage_id` / `form_definition_id` via master lookups (`debriefing_stages`, `debriefing_stage_applicability`, `debriefing_stage_forms`)
- `form_submission_data` built from `response` JSONB — special structured mapping for `'Debrief Level One Committe'` template
- `stage_type` hardcoded `'self'`; `sequence_order` from applicability mapping or array ordinality
- Form flags (`is_editable`, `is_reviewable`, `is_open_for_submission`) derived from feedback `status`
- Requires `seafarer_debriefs`, master debriefing stage tables migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `vessels`, `vessel_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `debrief_id_mapping` | FK lookup | `legacy_debrief_id`, `new_debrief_id` | `migration.table_mappings` (see SQL) | - |
| `stages_mapping` | FK lookup | `stage_id`, `stage_name`, `stage_code`, `stage_type`, `stage_mode` | - | `smac_master_migration` |
| `rank_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_type_id_mapping` | FK lookup | `legacy_vessel_type_id`, `new_vessel_type_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `debriefing_stage_applicability_mapping` | FK lookup | `applicability_id`, `t.stage_id`, `t.vessel_type_id`, `t.rank_id`, `sequence_order` | - | `smac_master_migration` |
| `debriefing_stage_forms_mapping` | FK lookup | `DISTINCT t.debriefing_stage_applicability_id`, `t.form_definition_id` | - | `smac_master_migration` |

### `debrief_id_mapping`

- **Output columns**: legacy_debrief_id, new_debrief_id
- **migration.table_mappings**: target_table=seafarer_debriefs

```sql
CREATE TEMP TABLE debrief_id_mapping AS
SELECT
    source_id::uuid as legacy_debrief_id,
    target_id as new_debrief_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_debriefs'
  AND target_db = current_database();
```

### `stages_mapping`

- **Output columns**: stage_id, stage_name, stage_code, stage_type, stage_mode
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE stages_mapping AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    code as stage_code,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, code, stage_type, stage_mode FROM crewing.debriefing_stages WHERE status = 0'
) AS t(id uuid, name text, code text, stage_type text, stage_mode text);
```

### `rank_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_rank_id,
    target_id as new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_type_id_mapping`

- **Output columns**: legacy_vessel_type_id, new_vessel_type_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_vessel_type_id,
    target_id as new_vessel_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `debriefing_stage_applicability_mapping`

- **Output columns**: applicability_id, t.stage_id, t.vessel_type_id, t.rank_id, sequence_order
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE debriefing_stage_applicability_mapping AS
SELECT DISTINCT
    t.id as applicability_id,
    t.stage_id,
    t.vessel_type_id,
    t.rank_id,
    t.stage_sequence as sequence_order
FROM dblink('smac_master_migration',
    'SELECT id, stage_id, vessel_type_id, rank_id, stage_sequence FROM crewing.debriefing_stage_applicability WHERE status = 0'
) AS t(id uuid, stage_id uuid, vessel_type_id uuid, rank_id uuid, stage_sequence integer);
```

### `debriefing_stage_forms_mapping`

- **Output columns**: DISTINCT t.debriefing_stage_applicability_id, t.form_definition_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE debriefing_stage_forms_mapping AS
SELECT DISTINCT
    t.debriefing_stage_applicability_id,
    t.form_definition_id
FROM dblink('smac_master_migration',
    'SELECT debriefing_stage_applicability_id, form_definition_id FROM crewing.debriefing_stage_forms WHERE status = 0'
) AS t(debriefing_stage_applicability_id uuid, form_definition_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per feedback array element |
| 2 | `id` | uuid | `debrief_id` | uuid | Direct copy (`appraisal_debrief.id`) | FK to `seafarer_debriefs.id` (preserved) |
| 3 | `feedback` → `templateName` | jsonb | `stage_id` | uuid | Join `stages_mapping` / `template_name_to_stage_mapping` | Lookup: `debriefing_stages` (`smac_master_migration`) |
| 4 | `feedback` (derived) | jsonb | `form_definition_id` | uuid | Join `debriefing_stage_forms_mapping` | Lookup via stage applicability |
| 5 | — | — | `stage_type` | text | Hardcoded `'self'` | Per migration requirements |
| 6 | `feedback` (derived) | jsonb | `stage_mode` | text | From `stages_mapping.stage_mode` | Master stage metadata |
| 7 | `feedback` (ordinality) | jsonb | `sequence_order` | integer | `COALESCE(dsa_map.sequence_order, ordinality - 1)` | From applicability or array index |
| 8 | — | — | `parallel_group` | text | `NULL` | No SAC equivalent |
| 9 | `feedback` → `response` | jsonb | `form_submission_data` | jsonb | Template-specific JSON build; special case for `Debrief Level One Committe` | Complex response normalization |
| 10 | `feedback` → `status` | jsonb | `form_status` | text | COMPLETED→`Completed`, PENDING→`Pending`; INITCAP fallback | From feedback element |
| 11 | `feedback` → `status` | jsonb | `is_editable` | boolean | `false` when COMPLETED; `true` for DRAFT/SUBMITTED | Derived from form status |
| 12 | `feedback` → `status` | jsonb | `is_reviewable` | boolean | Inverse logic of `is_editable` | Derived from form status |
| 13 | `feedback` → `status` | jsonb | `is_open_for_submission` | boolean | `false` when COMPLETED; `true` for DRAFT/SUBMITTED | Derived from form status |
| 14 | — | — | `escalation_from_level_id` | uuid | `NULL` | No SAC equivalent |
| 15 | — | — | `escalation_reason` | text | `NULL` | No SAC equivalent |
| 16 | `training_needs` | text | `training_needs_identified` | text | Direct copy | From parent debrief row |
| 17 | — | — | `remarks` | text | `NULL` | No SAC equivalent |
| 18 | `feedback` → `responded_at` | jsonb | `submitted_at` | timestamp | `TO_TIMESTAMP(DD/MM/YYYY)` when format matches | Parsed from feedback element |
| 19 | `feedback` → `debriefer_id` | jsonb | `submitted_by` | uuid | UUID cast when valid format | Submitter identity |
| 20 | `feedback` → `responded_at` | jsonb | `completed_at` | timestamp | Same parse as `submitted_at` | Completion timestamp |
| 21 | `feedback` → `debriefer_id` | jsonb | `completed_by` | uuid | Same UUID cast as `submitted_by` | Completer identity |
| 22 | — | — | `attachments` | jsonb | `NULL` | No SAC equivalent at level |
| 23 | — | — | `status` | text | Hardcoded `'Active'` | All migrated levels set Active |
| 24 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 25 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | From parent debrief row |
| 26 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | From parent debrief row |
| 27 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 28 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | From parent debrief row |
| 29 | `created_by_id`, `deleted_by`, `updated_by_id`, `id` | mixed | `audit_info` | jsonb | Standard SMAC structure with `legacy_id` | Custom audit from parent row |

**SMAC columns not migrated:** `parallel_group`, `escalation_from_level_id`, `escalation_reason`, `remarks`, `attachments`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** `rank_id`, `vessel_category_id`, `vessel_uuid`, `mark_for_deactivation`, `is_manual` — not used in level unpivot (parent debrief handles these).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `vessel_types`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Debrief ID Mapping
**Output columns**: `legacy_debrief_id, new_debrief_id`
**migration.table_mappings**: `target_table='seafarer_debriefs'`

```sql
CREATE TEMP TABLE debrief_id_mapping AS
SELECT
    source_id::uuid as legacy_debrief_id,
    target_id as new_debrief_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_debriefs'
  AND target_db = current_database();
```

### 2. Stages ID Mapping
**Output columns**: `stage_id, stage_name, stage_code, stage_type, stage_mode`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE stages_mapping AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    code as stage_code,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, code, stage_type, stage_mode FROM crewing.debriefing_stages WHERE status = 0'
) AS t(id uuid, name text, code text, stage_type text, stage_mode text);
```

### 3. Rank ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_rank_id,
    target_id as new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 4. Vessel Type ID Mapping
**Output columns**: `legacy_vessel_type_id, new_vessel_type_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_vessel_type_id,
    target_id as new_vessel_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 5. Debriefing Stage Applicability ID Mapping
**Output columns**: `applicability_id, t.stage_id, t.vessel_type_id, t.rank_id, sequence_order`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE debriefing_stage_applicability_mapping AS
SELECT DISTINCT
    t.id as applicability_id,
    t.stage_id,
    t.vessel_type_id,
    t.rank_id,
    t.stage_sequence as sequence_order
FROM dblink('smac_master_migration',
    'SELECT id, stage_id, vessel_type_id, rank_id, stage_sequence FROM crewing.debriefing_stage_applicability WHERE status = 0'
) AS t(id uuid, stage_id uuid, vessel_type_id uuid, rank_id uuid, stage_sequence integer);
```

### 6. Debriefing Stage Forms ID Mapping
**Output columns**: `DISTINCT t.debriefing_stage_applicability_id, t.form_definition_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE debriefing_stage_forms_mapping AS
SELECT DISTINCT
    t.debriefing_stage_applicability_id,
    t.form_definition_id
FROM dblink('smac_master_migration',
    'SELECT debriefing_stage_applicability_id, form_definition_id FROM crewing.debriefing_stage_forms WHERE status = 0'
) AS t(debriefing_stage_applicability_id uuid, form_definition_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_debrief_levels_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debrief_levels_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debrief_levels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
