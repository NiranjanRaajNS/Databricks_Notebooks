# Table Mapping: appraisal_templates → form_definitions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: appraisal_templates
- **New Database**: smac_master_migration
- **New Schema**: template
- **New Table**: form_definitions
- **Source Script**: `04-migration-scripts/master/form_definitions_for_appraisal_templates_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates`
- **New Path**: `smac_master_migration.template.form_definitions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `form_definitions`)

## Migration Notes

- Source: `synergy_master.public.appraisal_templates` → Target: `template.form_definitions`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- Requires `template.form_types` migrated first; `form_type_id` set from APPRAISAL code lookup
- Partial DELETE (not TRUNCATE): removes only APPRAISAL `form_type_id` rows and prior appraisal_templates mappings
- Two INSERT blocks: (1) all non-Appraisee templates; (2) single latest Appraisee → name `'Appraisee feedback'`
- Filter: `id IS NOT NULL`, Active status (`status` NULL/ACTIVE/0), `deleted_at IS NULL`, non-empty `template_name`
- `rank_name_lookup` temp table: maps `seafarer_rank_id` → rank name via `migration.table_mappings` + `public.ranks`
- `status` Case 2 from `deleted_at` + `status` text; `workflow_status`/`defined_by` from `constants.sql`
- Post-migration CSV export of inserted rows
- Mappings stored via `resolve_target_id()` only; `temp_mapping_data` populated but `store_table_mappings()` not called
## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `rank_name_lookup` | FK lookup | `seafarer_rank_id`, `rank_name` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `temp_form_definitions_export` | FK lookup | `fd.id`, `fd.code`, `fd.name`, `fd.description`, `fd.form_type_id`, `fd.form_template`, `fd.collaboration_level`, `fd.request_data_json`, `fd.report_template`, `fd.module_id`, `fd.tenant_id`, `fd.parent_id`, `fd.level`, `fd.version`, `fd.defined_by`, `fd.workflow_status`, `fd.status`, `fd.created_at`, `fd.updated_at`, `fd.deleted_at`, `fd.archived_at`, `fd.audit_info`, `fd.tags` | `?.?.appraisal_templates` → `?.?.form_definitions` | - |

### `rank_name_lookup`

- **Output columns**: seafarer_rank_id, rank_name
- **migration.table_mappings**: target_table=ranks
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT DISTINCT
    source_rank.identifier AS seafarer_rank_id,
    target_rank.name AS rank_name
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS source_rank(
    id bigint,
    identifier uuid
)
JOIN migration.table_mappings tm ON tm.source_id = source_rank.id::text
JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database();
```

### `temp_form_definitions_export`

- **Output columns**: fd.id, fd.code, fd.name, fd.description, fd.form_type_id, fd.form_template, fd.collaboration_level, fd.request_data_json, fd.report_template, fd.module_id, fd.tenant_id, fd.parent_id, fd.level, fd.version, fd.defined_by, fd.workflow_status, fd.status, fd.created_at, fd.updated_at, fd.deleted_at, fd.archived_at, fd.audit_info, fd.tags
- **migration.table_mappings**: source_table=appraisal_templates, target_table=form_definitions

```sql
CREATE TEMP TABLE temp_form_definitions_export AS
SELECT
    fd.id,
    fd.code,
    fd.name,
    fd.description,
    fd.form_type_id,
    fd.form_template,
    fd.collaboration_level,
    fd.request_data_json,
    fd.report_template,
    fd.module_id,
    fd.tenant_id,
    fd.parent_id,
    fd.level,
    fd.version,
    fd.defined_by,
    fd.workflow_status,
    fd.status,
    fd.created_at,
    fd.updated_at,
    fd.deleted_at,
    fd.archived_at,
    fd.audit_info,
    fd.tags
FROM template.form_definitions fd
WHERE fd.id IN (
    SELECT target_id::uuid
    FROM migration.table_mappings
    WHERE target_table = 'form_definitions'
      AND target_db = current_database()
      AND source_table = 'appraisal_templates'
)
ORDER BY fd.created_at, fd.name;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Pattern 4; idempotent |
| 2 | `template_name` | text | `code` | text | `UPPER(REGEXP_REPLACE(TRIM(template_name), '[^A-Za-z0-9]', '_', 'g'))` | NOT NULL |
| 3 | `template_name, template_type, seafarer_rank_id` | text, text, uuid | `name` | text | CASE: Appraisee → `'Appraisee feedback'`; contains `'form for'` → as-is; rank match → `'{Name} form for {Rank}'`; else `TRIM(template_name)` | NOT NULL |
| 4 | `template_name` | text | `description` | text | `NULLIF(TRIM(template_name), '')` | Optional |
| 5 | `—` | — | `form_type_id` | uuid | Session var from `template.form_types` where `code = 'APPRAISAL'` | FK lookup; NOT NULL |
| 6 | `template` | jsonb | `form_template` | jsonb | `COALESCE(template, '{}'::jsonb)` | NOT NULL |
| 7 | `—` | — | `collaboration_level` | integer | Hardcoded `0` | NOT NULL |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 9 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 10 | `version` | integer | `version` | integer | `COALESCE(version, 1)` |  |
| 11 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` |  |
| 13 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 14 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 15 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit user fields NULL | Pattern 4; no `legacy_id` |
| 16 | `—` | — | `request_data_json` | jsonb | `NULL` |  |
| 17 | `—` | — | `module_id` | uuid | `NULL` |  |
| 18 | `—` | — | `level` | numeric | `NULL` |  |
| 19 | `—` | — | `tags` | text[] | `NULL` |  |
| 20 | `deleted_at, status` | timestamp, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 21 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 22 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 23 | `—` | — | `report_template` | text | `NULL` |  |

**SAC columns not migrated:** `template_type` (used only in filters), `seafarer_rank_id` (lookup for name formatting only).

**SMAC columns not migrated:** None beyond defaults above.",
)

# --- form_definitions ---
set_update(
    "form_definitions",
    [
        "- Sources: `synergy_master.public.appraisal_templates` UNION ALL `debrief_templates` → `template.form_definitions`",
        "- `COALESCE(id, gen_random_uuid())` preserves legacy UUID when present (no `resolve_target_id`)",
        "- TRUNCATE `template.form_definitions`; clears all `form_definitions` mappings",
        "- `form_type_id_mapping` temp table: joins `template_type` name → `template.form_types.id`",
        "- Filter: `template_name IS NOT NULL AND TRIM(template_name) <> ''`",
        "- `status` Case 2; `workflow_status`/`defined_by` hardcoded `0` (not constants.sql vars in INSERT)",
        "- `tenant_id` hardcoded UUID (not `DEFAULT_TENANT_ID` psql var)",
        "- Post-migration: SurveyJS → Form.io conversion via `migration.convert_surveyjs_to_formio()` UPDATE on all rows",
        "- Mapping storage joins `audit_info->>'legacy_id'` (note: INSERT audit_info has no legacy_id)",
    ],
    [
        row(1, "id", "uuid", "id", "uuid", "`COALESCE(id, gen_random_uuid())`", "Preserves legacy UUID
## Foreign Key Dependencies

### Prerequisites (from source script)

- `form_types`
- `template.form_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Rank Name ID Mapping
**Output columns**: `seafarer_rank_id, rank_name`
**migration.table_mappings**: `target_table='ranks'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT DISTINCT
    source_rank.identifier AS seafarer_rank_id,
    target_rank.name AS rank_name
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS source_rank(
    id bigint,
    identifier uuid
)
JOIN migration.table_mappings tm ON tm.source_id = source_rank.id::text
JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database();
```

### 2. Temp Form Definitions Export ID Mapping
**Output columns**: `fd.id, fd.code, fd.name, fd.description, fd.form_type_id, fd.form_template, fd.collaboration_level, fd.request_data_json, fd.report_template, fd.module_id, fd.tenant_id, fd.parent_id, fd.level, fd.version, fd.defined_by, fd.workflow_status, fd.status, fd.created_at, fd.updated_at, fd.deleted_at, fd.archived_at, fd.audit_info, fd.tags`
**migration.table_mappings**: `appraisal_templates` → `form_definitions`

```sql
CREATE TEMP TABLE temp_form_definitions_export AS
SELECT
    fd.id,
    fd.code,
    fd.name,
    fd.description,
    fd.form_type_id,
    fd.form_template,
    fd.collaboration_level,
    fd.request_data_json,
    fd.report_template,
    fd.module_id,
    fd.tenant_id,
    fd.parent_id,
    fd.level,
    fd.version,
    fd.defined_by,
    fd.workflow_status,
    fd.status,
    fd.created_at,
    fd.updated_at,
    fd.deleted_at,
    fd.archived_at,
    fd.audit_info,
    fd.tags
FROM template.form_definitions fd
WHERE fd.id IN (
    SELECT target_id::uuid
    FROM migration.table_mappings
    WHERE target_table = 'form_definitions'
      AND target_db = current_database()
      AND source_table = 'appraisal_templates'
)
ORDER BY fd.created_at, fd.name;
```

Full migration context: `04-migration-scripts/master/form_definitions_for_appraisal_templates_migration.sql`

## Validation

- Run `05-validation/master/form_definitions_for_appraisal_templates_validation.sql` if available
- Run `06-rollback/master/form_definitions_for_appraisal_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
