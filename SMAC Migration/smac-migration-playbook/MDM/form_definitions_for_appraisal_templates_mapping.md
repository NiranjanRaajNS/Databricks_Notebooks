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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Only delete records with APPRAISAL form_type_id (not truncate - preserves other form_definitions)
- Migrates form_definions from appraisal_templates table

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'appraisal_templates'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | template_name | - | code | - | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) |
| 3 | template_name | - | name | - | CASE WHEN UPPER(TRIM(legacy_data.template_name)) = 'APPRAISEE' THEN 'Appraisee feedback' WHEN UPPER(TRIM(legacy_data.template_name)) LIKE '%FORM FOR%' THEN TRIM(legacy_data.temp... | CASE WHEN UPPER(TRIM(legacy_data.template_name)) = 'APPRAISEE' THEN 'Appraisee feedback' WHEN UPPER(TRIM(legacy_data.template_name)) LIKE '%FORM FOR%' THEN TRIM(legacy_data.temp... |
| 4 | template_name | - | description | - | NULLIF(TRIM(legacy_data.template_name), '') as description | NULLIF(TRIM(legacy_data.template_name), '') |
| 5 | derived | - | form_type_id | - | current_setting('migration.appraisal_form_type_id')::uuid as form_type_id | current_setting('migration.appraisal_form_type_id')::uuid |
| 6 | template | - | form_template | - | COALESCE(legacy_data.template, '{}'::jsonb) as form_template | COALESCE(legacy_data.template, '{}'::jsonb) |
| 7 | derived | - | collaboration_level | - | 0 as collaboration_level | 0 |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | version | - | version | - | COALESCE(legacy_data.version, 1) as version | COALESCE(legacy_data.version, 1) |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar ) |
| 16 | - | - | request_data_json | - | NULL | NULL::jsonb |
| 17 | - | - | module_id | - | NULL | NULL::uuid |
| 18 | - | - | level | - | NULL | NULL::numeric |
| 19 | - | - | tags | - | NULL | NULL::text[] |
| 20 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 21 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 22 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 23 | - | - | report_template | - | NULL | NULL::text |

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
