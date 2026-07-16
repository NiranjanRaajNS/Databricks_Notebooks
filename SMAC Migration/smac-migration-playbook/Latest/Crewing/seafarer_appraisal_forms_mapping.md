# Table Mapping: appraisals → seafarer_appraisal_forms

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisals (`feedback` JSONB array)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisal_forms
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisal_forms_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisals`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisal_forms`

## Business Key

- **Composite Key**: (`id`, array ordinality) — SAC appraisal `id` + position within `feedback` JSONB array
- **Source (orchestration)**: Appraisals (`appraisals` → `seafarer_appraisal_forms`)

## Migration Notes

- SAC `appraisals.feedback` JSONB array is unnested — one SMAC row per array element (`jsonb_array_elements` with ordinality)
- Composite source key: `id::text || '_' || form_idx` via `migration.resolve_target_id()` with `p_target_id = NULL`
- `appraisal_id` mapped via `appraisal_id_mapping` (`target_table = 'seafarer_appraisals'`); rows without mapping are excluded
- `form_definition_id` from `form_definition_id_mapping` — match `feedback.appraisal_template_id` to `template.form_definitions.id`
- `stage_id` / `stage_type` / `stage_mode` from `stage_id_mapping` — match `feedback.templateName` to `crewing.appraisal_stages.name` (case-insensitive)
- Form fields extracted from JSONB: `appraisal_template_id`, `templateName`, `templateType`, `templaterank`, `appraiser_id`, `appraiser_name`, `status`, `response`, `rating`, `responded_at`
- Filter: `feedback` is non-empty JSONB array; `appraisal_template_id` must be non-null and non-empty
- `status` hardcoded `'active'` (string); `form_template` empty JSONB `{}`
- `audit_info` via `migration.build_audit_info()` with appraiser name in `notes`
- Mappings stored automatically by `migration.resolve_target_id()`
- Script performs `TRUNCATE TABLE public.seafarer_appraisal_forms` before insert (full table reload)
- Requires `seafarer_appraisals` migrated first (table data + `migration.table_mappings`)

## Special Considerations

- One SAC appraisal row can produce multiple SMAC rows when `feedback` contains multiple array elements
- Parent appraisal audit columns (`created_by_id`, `updated_by_id`, `created_at`, `updated_at`, `deleted_at`) applied to all unnested form rows
- A follow-up enrichment migration (`seafarer_appraisal_form_update_migration.sql`) inserts additional enriched records for selected ranks — see **Enrichment Migration** below
- Orchestration dependencies: `seafarers` (via `seafarer_appraisals`)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script.

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
| 1 | `-` | - | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text \|\| '_' \|\| form_idx`; `p_target_id = NULL` | Idempotent; one row per feedback array element |
| 2 | `id` | bigint | `appraisal_id` | uuid | Map via `appraisal_id_mapping` (`target_table = 'seafarer_appraisals'`) | Required; unmapped rows excluded |
| 3 | `feedback` (JSONB) → `appraisal_template_id` | jsonb | `form_definition_id` | uuid | `COALESCE(fd_map.form_definition_id, nil UUID)` | Match to `template.form_definitions.id`; default nil UUID |
| 4 | `feedback` (JSONB) → `templateName` | jsonb | `stage_id` | uuid | Join `stage_id_mapping` on `UPPER(TRIM(stage_name)) = UPPER(TRIM(templateName))` | From SMAC `crewing.appraisal_stages` |
| 5 | `feedback` → `templateType`, stage lookup | jsonb, text | `stage_type` | text | `COALESCE(stage_map.stage_type, form_data->>'templateType', 'Unknown')` | |
| 6 | via stage lookup | text | `stage_mode` | text | `COALESCE(stage_map.stage_mode, 'Sequential')` | Default Sequential |
| 7 | `feedback` → `templaterank` | jsonb | `sequence_order` | integer | `COALESCE((form_data->>'templaterank')::integer, 0)` | |
| 8 | — | — | `parallel_group` | text | `NULL` | No equivalent in SAC feedback JSONB |
| 9 | `feedback` → `appraiser_id` | jsonb | `assigned_to_user_id` | uuid | Valid UUID regex from JSONB; else nil UUID | |
| 10 | `feedback` → `templateType` | jsonb | `assigned_to_user_type` | text | `COALESCE(form_data->>'templateType', 'Unknown')` | |
| 11 | — | — | `assigned_to_position_id` | uuid | `NULL` | Not in SAC |
| 12 | `feedback` → `status` | jsonb | `form_status` | text | `COALESCE(form_data->>'status', 'Pending')` | |
| 13 | — | — | `is_editable` | boolean | Hardcoded `false` | Overridden by enrichment migration for DRAFT/SUBMITTED |
| 14 | `feedback` → `status` | jsonb | `is_reviewable` | boolean | `status = 'COMPLETED'` → true | - |
| 15 | `feedback` → `status` | jsonb | `is_open_for_submission` | boolean | `status = 'Pending'` → true | - |
| 16 | — | — | `form_template` | jsonb | `'{}'::jsonb` | Empty template (NOT NULL); populated by enrichment migration |
| 17 | `feedback` → `response` | jsonb | `submission_data` | jsonb | Cast `response` string to jsonb when non-empty | Enrichment migration uses SurveyJS→Form.io mapping |
| 18 | — | — | `confirmation_data` | jsonb | `NULL` | Populated by enrichment migration for Master/CE |
| 19 | — | — | `suitable_for_promotion` | text | `NULL` | At appraisal level; populated by enrichment migration |
| 20 | — | — | `started_at` | timestamp without time zone | `NULL` | Not in SAC |
| 21 | `feedback` → `responded_at` | jsonb | `submitted_at` | timestamp without time zone | Cast to timestamp when non-empty | Enrichment migration handles DD-MM-YYYY format |
| 22 | — | — | `attachments` | jsonb | `NULL` | Not in SAC feedback |
| 23 | — | — | `status` | text | Hardcoded `'active'` | String status in initial migration; integer in enrichment migration |
| 24 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 25 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From parent appraisal |
| 26 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | From parent appraisal |
| 27 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC |
| 28 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | From parent appraisal |
| 29 | `created_by_id`, `updated_by_id`, `feedback` → `appraiser_name` | bigint, jsonb | `audit_info` | jsonb | `migration.build_audit_info()` — appraiser name in `notes` | Standardized SMAC audit structure; `legacy_id` via `id_mappings` |
| 30 | `feedback` → `rating` | jsonb | `average_score` | numeric(5,2) | Cast to numeric when non-empty | Enrichment migration adds `extract_rating_from_response` fallback |
| 31 | — | — | `other_training` | text | `NULL` | - |
| 32 | — | — | `slm_training_needs` | text[] | `NULL` | - |
| 33 | — | — | `training_needs` | text[] | `NULL` | - |

**SMAC columns not migrated at INSERT (initial):** `confirmation_data`, `suitable_for_promotion`, `other_training`, `slm_training_needs`, `training_needs` — NULL; populated by enrichment migration for eligible records.

**SAC columns not migrated:** Other `appraisals` columns (`rank_id`, `vessel_category_id`, `appraisal_type_id`, `is_manual`, etc.) — migrated to `seafarer_appraisals`; only `feedback` array is unnested in initial migration. Enrichment migration reads additional appraisal columns for advanced form resolution.

### Enrichment Migration

#### `seafarer_appraisal_form_update_migration.sql`

Re-processes SAC `appraisals.feedback` with advanced SMAC master lookups and inserts enriched records into existing `public.seafarer_appraisal_forms`. Does **not** TRUNCATE — uses `gen_random_uuid()` for new rows (not `resolve_target_id()`).

**Additional SAC filters:**
- `is_manual = false`
- `rank_id IN (13, 18, 17)` — Deck Cadet, Master, Chief Engineer
- Template type/name restrictions per rank (Appraisee, Deck Cadet stages, Master/CE superintendent feedback templates, Manager Feedback, etc.)
- `DISTINCT ON (appraisal_id, appraisal_template_id)` deduplicates source data quality issues

**Additional lookup tables (12 total):** `rank_id_mapping`, `vessel_type_id_mapping`, `appraisal_type_id_mapping`, `stage_info_lookup`, `appraisal_template_lookup`, `appraisal_stage_applicability_lookup`, `appraisal_stage_forms_lookup`, `rank_identifier_lookup`, `rank_name_lookup`, `appraisal_template_by_id_lookup`, `form_definition_template_lookup` — see `seafarer_appraisal_form_update_mapping.md` for full detail.

| Target Column | Enrichment Transformation | Notes |
|---------------|---------------------------|-------|
| `id` | `gen_random_uuid()` | New UUID per enriched row |
| `form_definition_id` | From `appraisal_stage_forms` via `appraisal_stage_applicability` (rank + vessel type + appraisal type + template name) | Replaces direct `form_definitions.id` match |
| `stage_id` | From `appraisal_stage_applicability.stage_id` | Resolved via template name → stage name matching with special cases |
| `stage_mode` | Appraiser stage → Sequential for non-Master/CE ranks; else from `appraisal_stages` | |
| `sequence_order` | `appraisal_stage_applicability.stage_sequence` | Replaces `templaterank` |
| `assigned_to_user_type` | From `appraisal_stage_forms.assigned_to_user_type` | Replaces `templateType` |
| `is_editable` | `true` when form_status IN (`DRAFT`, `SUBMITTED`) | |
| `is_reviewable` | `true` when form_status = `COMPLETED` (case-insensitive) | |
| `is_open_for_submission` | `true` when PENDING and all prior stages (by `stage_sequence`) are COMPLETED | Window function over appraisal forms |
| `form_template` | From `template.form_definitions.form_template` JSONB | Replaces empty `{}` |
| `submission_data` | SurveyJS→Form.io via `map_surveyjs_to_formio*`, `map_appraisal_response_data` by template type/rank | Rank/template-specific hardcoded mappings |
| `confirmation_data` | `migration.extract_confirmation_data()` for Master/CE ranks | Uses `seafarer_appraisals` period dates |
| `suitable_for_promotion` | `true`→`'yes'`, `false`→`'no'` from `appraisals.suitable_for_promotion` | |
| `submitted_at` | Multi-format date parsing (DD-MM-YYYY, ISO) for `responded_at` | |
| `status` | Integer: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) | Replaces hardcoded `'active'` string |
| `average_score` | `form_data.rating` or `migration.extract_rating_from_response()` fallback | |
| `other_training` | Direct from `appraisals.other_training` | |
| `slm_training_needs` | Direct from `appraisals.slm_training_needs` | |
| `training_needs` | Direct from `appraisals.training_needs` | |

**Prerequisites:** `seafarer_appraisals` migrated; SMAC master tables (`appraisal_stages`, `appraisal_stage_applicability`, `appraisal_stage_forms`, `form_definitions`, `appraisal_templates`) available.

Full enrichment context: `04-migration-scripts/crewing/seafarer_appraisal_form_update_migration.sql`

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_appraisals`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables — see **ID Mappings** section above.

Key transformation patterns:
- **Appraisal FK**: Legacy `appraisals.id` (bigint) → `seafarer_appraisals.id` (uuid) via `migration.table_mappings`
- **Form definition**: Initial migration matches `feedback.appraisal_template_id` directly to `template.form_definitions.id`; enrichment uses `appraisal_stage_applicability` + `appraisal_stage_forms` chain
- **Stage resolution**: Initial migration matches `feedback.templateName` to `appraisal_stages.name`; enrichment adds special-case name mappings (e.g. `Appraisee Feedback` → `Appraisee Acknowledgement`)
- **Response transformation**: Initial migration casts `response` to jsonb; enrichment applies rank/template-specific SurveyJS→Form.io mapping functions

Full migration context: `04-migration-scripts/crewing/seafarer_appraisal_forms_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_appraisal_forms_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisal_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
