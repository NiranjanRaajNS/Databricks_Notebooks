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

- source_id can be bigint (numeric) or UUID (text), so we filter for numeric only
- Migrates appraisal_debrief to seafarer_debriefs table. Preserves legacy UUID id directly. Maps seafarer_uuid (uuid) to seafarer_id (uuid) via migration.table_mappings. Maps vessel_uuid (uuid) to vessel_id (uuid) via migration.table_mappings from smac_master_migration. Maps vessel_category_id (bigint) to vessel_type_id (uuid) via migration.table_mappings from smac_master_migration. Converts attachments (text[]) to jsonb. Maps debrief_status to both current_stage and status. Conditional mapping for closed_by/closed_at based on debrief_status. Requires seafarers, vessels, and vessel_types tables to be migrated first.

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
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | id | - | debrief_id | - | legacy_data.id as debrief_id | legacy_data.id |
| 3 | derived | - | stage_id | - | stage_map.stage_id | stage_map.stage_id |
| 4 | derived | - | form_definition_id | - | dsf_map.form_definition_id | dsf_map.form_definition_id |
| 5 | derived | - | stage_type | - | 'self'::text as stage_type | 'self'::text |
| 6 | derived | - | stage_mode | - | stage_map.stage_mode | stage_map.stage_mode |
| 7 | derived | - | sequence_order | - | COALESCE(dsa_map.sequence_order, fb.ordinality - 1) as sequence_order | COALESCE(dsa_map.sequence_order, fb.ordinality - 1) |
| 8 | - | - | parallel_group | - | NULL | NULL::text |
| 9 | id | - | form_submission_data | - | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'templateName', ''))) = 'DEBRIEF LEVEL ONE COMMITTE' THEN CASE WHEN fb.value->'response' IS NOT NULL THEN CASE WHEN jsonb_typeof(fb.valu... | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'templateName', ''))) = 'DEBRIEF LEVEL ONE COMMITTE' THEN CASE WHEN fb.value->'response' IS NOT NULL THEN CASE WHEN jsonb_typeof(fb.valu... |
| 10 | derived | - | form_status | - | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN 'Completed' WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'PENDING' THEN 'Pending' WHEN fb.va... | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN 'Completed' WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'PENDING' THEN 'Pending' WHEN fb.va... |
| 11 | derived | - | is_editable | - | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN false WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(CO... | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN false WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(CO... |
| 12 | derived | - | is_reviewable | - | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN true WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(COA... | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN true WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(COA... |
| 13 | derived | - | is_open_for_submission | - | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN false WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(CO... | CASE WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) = 'COMPLETED' THEN false WHEN UPPER(TRIM(COALESCE(fb.value->>'status', ''))) IN ('DRAFT', 'SUBMITTED') AND UPPER(TRIM(CO... |
| 14 | - | - | escalation_from_level_id | - | NULL | NULL::uuid as escalation_ |
| 15 | - | - | escalation_reason | - | See source script | See source script |
| 16 | - | - | training_needs_identified | - | See source script | See source script |
| 17 | - | - | remarks | - | See source script | See source script |
| 18 | - | - | submitted_at | - | See source script | See source script |
| 19 | - | - | submitted_by | - | See source script | See source script |
| 20 | - | - | completed_at | - | See source script | See source script |
| 21 | - | - | completed_by | - | See source script | See source script |
| 22 | - | - | attachments | - | See source script | See source script |
| 23 | - | - | status | - | See source script | See source script |
| 24 | - | - | tenant_id | - | See source script | See source script |
| 25 | - | - | created_at | - | See source script | See source script |
| 26 | - | - | updated_at | - | See source script | See source script |
| 27 | - | - | archived_at | - | See source script | See source script |
| 28 | - | - | deleted_at | - | See source script | See source script |
| 29 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
