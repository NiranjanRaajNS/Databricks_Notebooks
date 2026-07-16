# Table Mapping: seafarer_appraisal_forms → seafarer_appraisal_forms

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisal_forms
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisal_forms_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisals.feedback (JSONB array)`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisal_forms`

## Business Key

- **Composite Key**: (`seafarer_id`, `form_definitions_id`)
- **Source (orchestration)**: Appraisals (`appraisals` → `seafarer_appraisal_forms`)

## Migration Notes

- Extracts form data from appraisals.feedback JSONB array column
- Joins seafarer_other_details and seafarer_documents on seafarer_doc_id. Extracts submission_data from seafarer_documents.form_response JSONB. Maps seafarer_id via migration.table_mappings (try seafarer_uuid first, then seafarer_id). Maps is_confirmed to is_verified, verified_date to verified_at. Uses standardized SMAC audit_info structure. Only migrates records where form_response IS NOT NULL AND form_response::text <> '{}'.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_appraisal_forms` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `appraisal_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `form_definition_id_mapping` | FK lookup | `form_definition_id`, `template_id_text` | - | `smac_master_migration` |
| `stage_id_mapping` | FK lookup | `stage_id`, `stage_name`, `stage_type`, `stage_mode` | - | `smac_master_migration` |

### `appraisal_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_appraisals

```sql
CREATE TEMP TABLE appraisal_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_appraisals'
  AND target_db = current_database();
```

### `form_definition_id_mapping`

- **Output columns**: form_definition_id, template_id_text
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE form_definition_id_mapping AS
SELECT DISTINCT
    id as form_definition_id,
    id::text as template_id_text
FROM dblink('smac_master_migration',
    'SELECT id FROM template.form_definitions WHERE status = 0'
) AS t(id uuid);
```

### `stage_id_mapping`

- **Output columns**: stage_id, stage_name, stage_type, stage_mode
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE stage_id_mapping AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, stage_type, stage_mode FROM crewing.appraisal_stages WHERE status = 0'
) AS t(id uuid, name text, stage_type text, stage_mode text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'appraisals'::VARCHAR(100), (legacy_data.id::text || '_' || form_idx::text)::text, current... |
| 2 | derived | - | appraisal_id | - | appraisal_map.new_id AS appraisal_id | appraisal_map.new_id |
| 3 | derived | - | form_definition_id | - | COALESCE(fd_map.form_definition_id, '00000000-0000-0000-0000-000000000000'::uuid) AS form_definition_id | COALESCE(fd_map.form_definition_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | stage_id | - | stage_map.stage_id AS stage_id | stage_map.stage_id |
| 5 | derived | - | stage_type | - | COALESCE(stage_map.stage_type, form_data->>'templateType', 'Unknown') AS stage_type | COALESCE(stage_map.stage_type, form_data->>'templateType', 'Unknown') |
| 6 | derived | - | stage_mode | - | COALESCE(stage_map.stage_mode, 'Sequential') AS stage_mode | COALESCE(stage_map.stage_mode, 'Sequential') |
| 7 | derived | - | sequence_order | - | COALESCE((form_data->>'templaterank')::integer, 0) AS sequence_order | COALESCE((form_data->>'templaterank')::integer, 0) |
| 8 | - | - | parallel_group | - | NULL | NULL::text |
| 9 | derived | - | assigned_to_user_id | - | CASE WHEN form_data->>'appraiser_id' IS NOT NULL AND form_data->>'appraiser_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (form_data->>'appraiser_... | CASE WHEN form_data->>'appraiser_id' IS NOT NULL AND form_data->>'appraiser_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (form_data->>'appraiser_... |
| 10 | derived | - | assigned_to_user_type | - | COALESCE(form_data->>'templateType', 'Unknown') AS assigned_to_user_type | COALESCE(form_data->>'templateType', 'Unknown') |
| 11 | - | - | assigned_to_position_id | - | NULL | NULL::uuid |
| 12 | derived | - | form_status | - | COALESCE(form_data->>'status', 'Pending') AS form_status | COALESCE(form_data->>'status', 'Pending') |
| 13 | derived | - | is_editable | - | false AS is_editable | false |
| 14 | derived | - | is_reviewable | - | CASE WHEN form_data->>'status' = 'COMPLETED' THEN true ELSE false END AS is_reviewable | CASE WHEN form_data->>'status' = 'COMPLETED' THEN true ELSE false END |
| 15 | derived | - | is_open_for_submission | - | CASE WHEN form_data->>'status' = 'Pending' THEN true ELSE false END AS is_open_for_submission | CASE WHEN form_data->>'status' = 'Pending' THEN true ELSE false END |
| 16 | derived | - | form_template | - | '{}'::jsonb AS form_template | '{}'::jsonb |
| 17 | derived | - | submission_data | - | CASE WHEN form_data->>'response' IS NOT NULL AND form_data->>'response' != '' THEN form_data->>'response'::jsonb ELSE NULL END AS submission_data | CASE WHEN form_data->>'response' IS NOT NULL AND form_data->>'response' != '' THEN form_data->>'response'::jsonb ELSE NULL END |
| 18 | - | - | confirmation_data | - | NULL | NULL::jsonb |
| 19 | - | - | suitable_for_promotion | - | NULL | NULL::text |
| 20 | - | - | started_at | - | NULL | NULL::timestamp |
| 21 | derived | - | submitted_at | - | CASE WHEN form_data->>'responded_at' IS NOT NULL AND form_data->>'responded_at' != '' THEN (form_data->>'responded_at')::timestamp ELSE NULL END AS submitted_at | CASE WHEN form_data->>'responded_at' IS NOT NULL AND form_data->>'responded_at' != '' THEN (form_data->>'responded_at')::timestamp ELSE NULL END |
| 22 | - | - | attachments | - | NULL | NULL::jsonb |
| 23 | derived | - | status | - | 'active' AS status | 'active' |
| 24 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 25 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 26 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 27 | - | - | archived_at | - | NULL | NULL::timestamp |
| 28 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 29 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 30 | derived | - | average_score | - | CASE WHEN form_data->>'rating' IS NOT NULL AND form_data->>'rating' != '' THEN (form_data->>'rating')::numeric(5,2) ELSE NULL END AS average_score | CASE WHEN form_data->>'rating' IS NOT NULL AND form_data->>'rating' != '' THEN (form_data->>'rating')::numeric(5,2) ELSE NULL END |
| 31 | - | - | other_training | - | NULL | NULL::text |
| 32 | - | - | slm_training_needs | - | NULL | NULL::text[] |
| 33 | - | - | training_needs | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_appraisals`
- `seafarer_appraisals`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Appraisal ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_appraisals'`

```sql
CREATE TEMP TABLE appraisal_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_appraisals'
  AND target_db = current_database();
```

### 2. Form Definition ID Mapping
**Output columns**: `form_definition_id, template_id_text`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE form_definition_id_mapping AS
SELECT DISTINCT
    id as form_definition_id,
    id::text as template_id_text
FROM dblink('smac_master_migration',
    'SELECT id FROM template.form_definitions WHERE status = 0'
) AS t(id uuid);
```

### 3. Stage ID Mapping
**Output columns**: `stage_id, stage_name, stage_type, stage_mode`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE stage_id_mapping AS
SELECT DISTINCT
    id as stage_id,
    name as stage_name,
    stage_type,
    stage_mode
FROM dblink('smac_master_migration',
    'SELECT id, name, stage_type, stage_mode FROM crewing.appraisal_stages WHERE status = 0'
) AS t(id uuid, name text, stage_type text, stage_mode text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_appraisal_forms_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_appraisal_forms_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisal_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
