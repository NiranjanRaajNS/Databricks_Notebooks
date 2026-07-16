# Table Mapping: seafarer_appraisal_form_update → seafarer_appraisal_forms

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisal_forms
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisal_form_update_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisals.feedback (JSONB array)`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisal_forms`

## Business Key

- **Composite Key**: (`seafarer_id`, `form_definitions_id`)
- **Source (orchestration)**: Appraisals (`appraisals` → `seafarer_appraisal_forms`)

## Migration Notes

- Extracts form data from appraisals.feedback JSONB array column
- seafarer_appraisals uses integer ID as source_id (legacy_data.id::text)
- Joins seafarer_other_details and seafarer_documents on seafarer_doc_id. Extracts submission_data from seafarer_documents.form_response JSONB. Maps seafarer_id via migration.table_mappings (try seafarer_uuid first, then seafarer_id). Maps is_confirmed to is_verified, verified_date to verified_at. Uses standardized SMAC audit_info structure. Only migrates records where form_response IS NOT NULL AND form_response::text <> '{}'.

## Special Considerations

- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 12

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `appraisal_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_type_id_mapping` | FK lookup | `legacy_vessel_category_id`, `new_vessel_type_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `appraisal_type_id_mapping` | FK lookup | `legacy_appraisal_type_id`, `new_appraisal_type_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `stage_info_lookup` | FK lookup | `stage_id`, `stage_name`, `stage_type`, `stage_mode` | - | `smac_master_migration` |
| `appraisal_template_lookup` | FK lookup | `template_id_text`, `template_type`, `template_name` | - | `synergy_master` |
| `appraisal_stage_applicability_lookup` | Create vessel_type_id lookup mapping (from smac_mas | `stage_applicability_id`, `rank_id`, `vessel_type_id`, `appraisal_type_id`, `stage_id`, `stage_sequence`, `stage_name`, `stage_type` | - | `smac_master_migration` |
| `appraisal_stage_forms_lookup` | FK lookup | `DISTINCT t.stage_applicability_id`, `t.form_definition_id`, `t.stage_id`, `t.assigned_to_user_type` | - | `smac_master_migration` |
| `rank_identifier_lookup` | FK lookup | `legacy_rank_id`, `rank_identifier_uuid` | - | `synergy_master` |
| `rank_name_lookup` | Create appraisal_template_id to template_type and template_name lookup (from synergy | `rank_map.new_rank_id`, `rank_name` | - | `smac_master_migration` |
| `appraisal_template_by_id_lookup` | FK lookup | `template_id_text`, `source_template_jsonb` | - | `synergy_master` |
| `form_definition_template_lookup` | FK lookup | `form_definition_id`, `destination_template_jsonb` | - | `smac_master_migration` |

### `appraisal_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=seafarer_appraisals

```sql
CREATE TEMP TABLE appraisal_id_mapping AS
SELECT
    source_id::text as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_appraisals'
  AND target_db = current_database()
  AND (source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       OR source_id ~ '^[0-9]+$');
```

### `rank_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_rank_id,
    target_id as new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''ranks''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_type_id_mapping`

- **Output columns**: legacy_vessel_category_id, new_vessel_type_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_vessel_category_id,
    target_id as new_vessel_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''categories''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `appraisal_type_id_mapping`

- **Output columns**: legacy_appraisal_type_id, new_appraisal_type_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_type_id_mapping AS
SELECT
    source_id::bigint as legacy_appraisal_type_id,
    target_id as new_appraisal_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''appraisal_types''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `stage_info_lookup`

- **Output columns**: stage_id, stage_name, stage_type, stage_mode
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE stage_info_lookup AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, stage_type, stage_mode FROM crewing.appraisal_stages WHERE status = 0'
) AS t(id uuid, name text, stage_type text, stage_mode text);
```

### `appraisal_template_lookup`

- **Output columns**: template_id_text, template_type, template_name
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE appraisal_template_lookup AS
SELECT DISTINCT
    id::text as template_id_text,
    template_type,
    template_name
FROM dblink('synergy_master',
    'SELECT id, template_type, template_name FROM public.appraisal_templates WHERE template_type IS NOT NULL'
) AS t(id uuid, template_type text, template_name text);
```

### `appraisal_stage_applicability_lookup`

- **Purpose**: Create vessel_type_id lookup mapping (from smac_mas
- **Output columns**: stage_applicability_id, rank_id, vessel_type_id, appraisal_type_id, stage_id, stage_sequence, stage_name, stage_type
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_stage_applicability_lookup AS
SELECT DISTINCT
    id as stage_applicability_id,
    rank_id,
    vessel_type_id,
    appraisal_type_id,
    stage_id,
    stage_sequence,
    stage_name,
    stage_type
FROM dblink('smac_master_migration',
    'SELECT asa.id, asa.rank_id, asa.vessel_type_id, asa.appraisal_type_id, asa.stage_id, asa.stage_sequence, ast.name as stage_name, ast.stage_type
     FROM crewing.appraisal_stage_applicability asa
     INNER JOIN crewing.appraisal_stages ast ON ast.id = asa.stage_id
     WHERE asa.status = 0 AND ast.status = 0'
) AS t(id uuid, rank_id uuid, vessel_type_id uuid, appraisal_type_id uuid, stage_id uuid, stage_sequence integer, stage_name text, stage_type text);
```

### `appraisal_stage_forms_lookup`

- **Output columns**: DISTINCT t.stage_applicability_id, t.form_definition_id, t.stage_id, t.assigned_to_user_type
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_stage_forms_lookup AS
SELECT DISTINCT
    t.stage_applicability_id,
    t.form_definition_id,
    t.stage_id,
    t.assigned_to_user_type
FROM dblink('smac_master_migration',
    'SELECT asf.stage_applicability_id, asf.form_definition_id, asa.stage_id, asf.assigned_to_user_type
     FROM crewing.appraisal_stage_forms asf
     INNER JOIN crewing.appraisal_stage_applicability asa ON asa.id = asf.stage_applicability_id
     WHERE asf.status = 0'
) AS t(stage_applicability_id uuid, form_definition_id uuid, stage_id uuid, assigned_to_user_type text);
```

### `rank_identifier_lookup`

- **Output columns**: legacy_rank_id, rank_identifier_uuid
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_lookup AS
SELECT DISTINCT
    r.id as legacy_rank_id,
    r.identifier as rank_identifier_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid);
```

### `rank_name_lookup`

- **Purpose**: Create appraisal_template_id to template_type and template_name lookup (from synergy
- **Output columns**: rank_map.new_rank_id, rank_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT
    rank_map.new_rank_id,
    r.name as rank_name
FROM rank_id_mapping rank_map
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks WHERE name IS NOT NULL'
) AS r(id uuid, name text) ON r.id = rank_map.new_rank_id;
```

### `appraisal_template_by_id_lookup`

- **Output columns**: template_id_text, source_template_jsonb
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE appraisal_template_by_id_lookup AS
SELECT DISTINCT
    at.id::text as template_id_text,
    at.template::jsonb as source_template_jsonb
FROM dblink('synergy_master',
    'SELECT id, template FROM public.appraisal_templates WHERE template IS NOT NULL'
) AS at(id uuid, template jsonb);
```

### `form_definition_template_lookup`

- **Output columns**: form_definition_id, destination_template_jsonb
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE form_definition_template_lookup AS
SELECT DISTINCT
    fd.id as form_definition_id,
    fd.form_template::jsonb as destination_template_jsonb
FROM dblink('smac_master_migration',
    'SELECT id, form_template FROM template.form_definitions WHERE form_template IS NOT NULL'
) AS fd(id uuid, form_template jsonb);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | DISTINCT ON (legacy_data.id, form_data->>'appraisal_template_id') gen_random_uuid() as id | DISTINCT ON (legacy_data.id, form_data->>'appraisal_template_id') gen_random_uuid() |
| 2 | derived | - | appraisal_id | - | appraisal_map.new_id AS appraisal_id | appraisal_map.new_id |
| 3 | derived | - | form_definition_id | - | asf_lookup.form_definition_id AS form_definition_id | asf_lookup.form_definition_id |
| 4 | derived | - | stage_id | - | asa_lookup.stage_id AS stage_id | asa_lookup.stage_id |
| 5 | derived | - | stage_type | - | COALESCE(asa_lookup.stage_type, stage_info_map.stage_type, 'Unknown') AS stage_type | COALESCE(asa_lookup.stage_type, stage_info_map.stage_type, 'Unknown') |
| 6 | derived | - | stage_mode | - | CASE WHEN COALESCE(asa_lookup.stage_type, stage_info_map.stage_type, '') = 'Appraiser' AND UPPER(TRIM(COALESCE(rank_name_lookup.rank_name, ''))) NOT IN ('MASTER', 'CHIEF ENGINEE... | CASE WHEN COALESCE(asa_lookup.stage_type, stage_info_map.stage_type, '') = 'Appraiser' AND UPPER(TRIM(COALESCE(rank_name_lookup.rank_name, ''))) NOT IN ('MASTER', 'CHIEF ENGINEE... |
| 7 | derived | - | sequence_order | - | COALESCE(asa_lookup.stage_sequence, 1) AS sequence_order | COALESCE(asa_lookup.stage_sequence, 1) |
| 8 | - | - | parallel_group | - | NULL | NULL::text |
| 9 | derived | - | assigned_to_user_id | - | CASE WHEN form_data->>'appraiser_id' IS NOT NULL AND form_data->>'appraiser_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (form_data->>'appraiser_... | CASE WHEN form_data->>'appraiser_id' IS NOT NULL AND form_data->>'appraiser_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (form_data->>'appraiser_... |
| 10 | derived | - | assigned_to_user_type | - | COALESCE(asf_lookup.assigned_to_user_type, 'Unknown') AS assigned_to_user_type | COALESCE(asf_lookup.assigned_to_user_type, 'Unknown') |
| 11 | - | - | assigned_to_position_id | - | NULL | NULL::uuid |
| 12 | derived | - | form_status | - | COALESCE(form_data->>'status', 'Pending') AS form_status | COALESCE(form_data->>'status', 'Pending') |
| 13 | derived | - | is_editable | - | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) IN ('DRAFT', 'SUBMITTED') THEN true ELSE false END AS is_editable | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) IN ('DRAFT', 'SUBMITTED') THEN true ELSE false END |
| 14 | derived | - | is_reviewable | - | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) = 'COMPLETED' THEN true ELSE false END AS is_reviewable | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) = 'COMPLETED' THEN true ELSE false END |
| 15 | derived | - | is_open_for_submission | - | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) = 'PENDING' THEN CASE WHEN COALESCE(asa_lookup.stage_sequence, 0) <= COALESCE( MIN(CASE WHEN UPPER(TRIM(COALESCE... | CASE WHEN UPPER(TRIM(COALESCE(form_data->>'status', 'Pending'))) = 'PENDING' THEN CASE WHEN COALESCE(asa_lookup.stage_sequence, 0) <= COALESCE( MIN(CASE WHEN UPPER(TRIM(COALESCE... |
| 16 | derived | - | form_template | - | COALESCE(dest_template_lookup.destination_template_jsonb, '{}'::jsonb) AS form_template | COALESCE(dest_template_lookup.destination_template_jsonb, '{}'::jsonb) |
| 17 | derived | - | submission_data | - | to_jsonb(( CASE WHEN form_data->'response' IS NOT NULL AND form_data->'response' != 'null'::jsonb AND (jsonb_typeof(form_data->'response') = 'string' OR (jsonb_typeof(form_data-... | to_jsonb(( CASE WHEN form_data->'response' IS NOT NULL AND form_data->'response' != 'null'::jsonb AND (jsonb_typeof(form_data->'response') = 'string' OR (jsonb_typeof(form_data-... |
| 18 | derived | - | confirmation_data | - | CASE WHEN UPPER(TRIM(COALESCE(rank_name_lookup.rank_name, ''))) IN ('MASTER', 'CHIEF ENGINEER') AND form_data->'response' IS NOT NULL AND form_data->'response' != 'null'::jsonb ... | CASE WHEN UPPER(TRIM(COALESCE(rank_name_lookup.rank_name, ''))) IN ('MASTER', 'CHIEF ENGINEER') AND form_data->'response' IS NOT NULL AND form_data->'response' != 'null'::jsonb ... |
| 19 | suitable_for_promotion | - | suitable_for_promotion | - | CASE WHEN legacy_data.suitable_for_promotion = true THEN 'yes' WHEN legacy_data.suitable_for_promotion = false THEN 'no' ELSE NULL END AS suitable_for_promotion | CASE WHEN legacy_data.suitable_for_promotion = true THEN 'yes' WHEN legacy_data.suitable_for_promotion = false THEN 'no' ELSE NULL END |
| 20 | - | - | started_at | - | NULL | NULL::timestamp |
| 21 | derived | - | submitted_at | - | CASE WHEN form_data->>'responded_at' IS NOT NULL AND form_data->>'responded_at' != '' THEN CASE WHEN (form_data->>'responded_at')::text ~ '^\d{2}-\d{2}-\d{4}' THEN TO_TIMESTAMP(... | CASE WHEN form_data->>'responded_at' IS NOT NULL AND form_data->>'responded_at' != '' THEN CASE WHEN (form_data->>'responded_at')::text ~ '^\d{2}-\d{2}-\d{4}' THEN TO_TIMESTAMP(... |
| 22 | - | - | attachments | - | NULL | NULL::jsonb |
| 23 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 24 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 25 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 26 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 27 | - | - | archived_at | - | NULL | NULL::timestamp |
| 28 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 29 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 30 | derived | - | average_score | - | COALESCE( CASE WHEN form_data->>'rating' IS NOT NULL AND form_data->>'rating' != '' AND form_data->>'rating' != 'null' AND (form_data->>'rating') ~ '^[0-9]+\.?[0-9]*$' THEN (for... | COALESCE( CASE WHEN form_data->>'rating' IS NOT NULL AND form_data->>'rating' != '' AND form_data->>'rating' != 'null' AND (form_data->>'rating') ~ '^[0-9]+\.?[0-9]*$' THEN (for... |
| 31 | other_training | - | other_training | - | legacy_data.other_training AS other_training | legacy_data.other_training |
| 32 | slm_training_needs | - | slm_training_needs | - | legacy_data.slm_training_needs AS slm_training_needs | legacy_data.slm_training_needs |
| 33 | training_needs | - | training_needs | - | legacy_data.training_needs AS training_needs | legacy_data.training_needs |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Appraisal ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='seafarer_appraisals'`

```sql
CREATE TEMP TABLE appraisal_id_mapping AS
SELECT
    source_id::text as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_appraisals'
  AND target_db = current_database()
  AND (source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       OR source_id ~ '^[0-9]+$');
```

### 2. Rank ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::bigint as legacy_rank_id,
    target_id as new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''ranks''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 3. Vessel Type ID Mapping
**Output columns**: `legacy_vessel_category_id, new_vessel_type_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_type_id_mapping AS
SELECT
    source_id::bigint as legacy_vessel_category_id,
    target_id as new_vessel_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''categories''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 4. Appraisal Type ID Mapping
**Output columns**: `legacy_appraisal_type_id, new_appraisal_type_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_type_id_mapping AS
SELECT
    source_id::bigint as legacy_appraisal_type_id,
    target_id as new_appraisal_type_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''appraisal_types''
       AND target_db = current_database()
       AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 5. Stage Info ID Mapping
**Output columns**: `stage_id, stage_name, stage_type, stage_mode`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE stage_info_lookup AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, stage_type, stage_mode FROM crewing.appraisal_stages WHERE status = 0'
) AS t(id uuid, name text, stage_type text, stage_mode text);
```

### 6. Appraisal Template ID Mapping
**Output columns**: `template_id_text, template_type, template_name`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE appraisal_template_lookup AS
SELECT DISTINCT
    id::text as template_id_text,
    template_type,
    template_name
FROM dblink('synergy_master',
    'SELECT id, template_type, template_name FROM public.appraisal_templates WHERE template_type IS NOT NULL'
) AS t(id uuid, template_type text, template_name text);
```

### 7. Appraisal Stage Applicability ID Mapping
**Purpose**: Create vessel_type_id lookup mapping (from smac_mas
**Output columns**: `stage_applicability_id, rank_id, vessel_type_id, appraisal_type_id, stage_id, stage_sequence, stage_name, stage_type`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_stage_applicability_lookup AS
SELECT DISTINCT
    id as stage_applicability_id,
    rank_id,
    vessel_type_id,
    appraisal_type_id,
    stage_id,
    stage_sequence,
    stage_name,
    stage_type
FROM dblink('smac_master_migration',
    'SELECT asa.id, asa.rank_id, asa.vessel_type_id, asa.appraisal_type_id, asa.stage_id, asa.stage_sequence, ast.name as stage_name, ast.stage_type
     FROM crewing.appraisal_stage_applicability asa
     INNER JOIN crewing.appraisal_stages ast ON ast.id = asa.stage_id
     WHERE asa.status = 0 AND ast.status = 0'
) AS t(id uuid, rank_id uuid, vessel_type_id uuid, appraisal_type_id uuid, stage_id uuid, stage_sequence integer, stage_name text, stage_type text);
```

### 8. Appraisal Stage Forms ID Mapping
**Output columns**: `DISTINCT t.stage_applicability_id, t.form_definition_id, t.stage_id, t.assigned_to_user_type`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE appraisal_stage_forms_lookup AS
SELECT DISTINCT
    t.stage_applicability_id,
    t.form_definition_id,
    t.stage_id,
    t.assigned_to_user_type
FROM dblink('smac_master_migration',
    'SELECT asf.stage_applicability_id, asf.form_definition_id, asa.stage_id, asf.assigned_to_user_type
     FROM crewing.appraisal_stage_forms asf
     INNER JOIN crewing.appraisal_stage_applicability asa ON asa.id = asf.stage_applicability_id
     WHERE asf.status = 0'
) AS t(stage_applicability_id uuid, form_definition_id uuid, stage_id uuid, assigned_to_user_type text);
```

### 9. Rank Identifier ID Mapping
**Output columns**: `legacy_rank_id, rank_identifier_uuid`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_lookup AS
SELECT DISTINCT
    r.id as legacy_rank_id,
    r.identifier as rank_identifier_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid);
```

### 10. Rank Name ID Mapping
**Purpose**: Create appraisal_template_id to template_type and template_name lookup (from synergy
**Output columns**: `rank_map.new_rank_id, rank_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT
    rank_map.new_rank_id,
    r.name as rank_name
FROM rank_id_mapping rank_map
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks WHERE name IS NOT NULL'
) AS r(id uuid, name text) ON r.id = rank_map.new_rank_id;
```

### 11. Appraisal Template By Id ID Mapping
**Output columns**: `template_id_text, source_template_jsonb`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE appraisal_template_by_id_lookup AS
SELECT DISTINCT
    at.id::text as template_id_text,
    at.template::jsonb as source_template_jsonb
FROM dblink('synergy_master',
    'SELECT id, template FROM public.appraisal_templates WHERE template IS NOT NULL'
) AS at(id uuid, template jsonb);
```

### 12. Form Definition Template ID Mapping
**Output columns**: `form_definition_id, destination_template_jsonb`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE form_definition_template_lookup AS
SELECT DISTINCT
    fd.id as form_definition_id,
    fd.form_template::jsonb as destination_template_jsonb
FROM dblink('smac_master_migration',
    'SELECT id, form_template FROM template.form_definitions WHERE form_template IS NOT NULL'
) AS fd(id uuid, form_template jsonb);
```

Full migration context: `04-migration-scripts/crewing/seafarer_appraisal_form_update_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_appraisal_form_update_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisal_form_update_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
