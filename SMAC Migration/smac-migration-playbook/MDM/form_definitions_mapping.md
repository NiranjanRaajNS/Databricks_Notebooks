# Table Mapping: appraisal_templates + debrief_templates → form_definitions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: appraisal_templates + debrief_templates
- **New Database**: smac_master_migration
- **New Schema**: template
- **New Table**: form_definitions
- **Source Script**: `04-migration-scripts/master/form_definitions_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates + debrief_templates`
- **New Path**: `smac_master_migration.template.form_definitions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `form_definitions`)

## Migration Notes

- Combines data from both appraisal_templates and debrief_templates tables
- Preserves legacy UUID id when available
- Generates code from name using UPPER(REGEXP_REPLACE(TRIM(name), '[^A-Za-z0-9]', '_', 'g'))
- Maps template_type to form_type_id by looking up in template.form_types
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires template.form_types to be migrated first
- Migrates form_definions from appraisal_templates table

## Special Considerations

- Maps template (jsonb) to form_template (jsonb, NOT NULL)
- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE template.form_definitions` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `form_type_id_mapping` | FK lookup | `name`, `form_type_id` | - | - |

### `form_type_id_mapping`

- **Output columns**: name, form_type_id

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    name,
    id AS form_type_id
FROM template.form_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | COALESCE(legacy_data.id, gen_random_uuid()) as id | COALESCE(legacy_data.id, gen_random_uuid()) |
| 2 | template_name | - | code | - | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) |
| 3 | template_name | - | name | - | TRIM(legacy_data.template_name) as name | TRIM(legacy_data.template_name) |
| 4 | template_name | - | description | - | NULLIF(TRIM(legacy_data.template_name), '') as description | NULLIF(TRIM(legacy_data.template_name), '') |
| 5 | derived | - | form_type_id | - | COALESCE(ft_mapping.form_type_id, '00000000-0000-0000-0000-000000000000'::uuid) as form_type_id | COALESCE(ft_mapping.form_type_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | template | - | form_template | - | COALESCE(legacy_data.template, '{}'::jsonb) as form_template | COALESCE(legacy_data.template, '{}'::jsonb) |
| 7 | derived | - | collaboration_level | - | 0 as collaboration_level | 0 |
| 8 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | version | - | version | - | COALESCE(legacy_data.version, 1) as version | COALESCE(legacy_data.version, 1) |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 16 | - | - | request_data_json | - | NULL | NULL::jsonb |
| 17 | - | - | module_id | - | NULL | NULL::uuid |
| 18 | - | - | level | - | NULL | NULL::numeric |
| 19 | - | - | tags | - | NULL | NULL::text[] |
| 20 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 21 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 22 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 23 | - | - | report_template | - | NULL | NULL::text |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `form_types`
- `template.form_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Form Type ID Mapping
**Output columns**: `name, form_type_id`

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    name,
    id AS form_type_id
FROM template.form_types;
```

Full migration context: `04-migration-scripts/master/form_definitions_migration.sql`

## Validation

- Run `05-validation/master/form_definitions_validation.sql` if available
- Run `06-rollback/master/form_definitions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
