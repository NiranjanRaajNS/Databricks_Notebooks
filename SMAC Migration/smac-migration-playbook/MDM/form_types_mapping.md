# Table Mapping: form_types → form_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: template
- **New Table**: form_types
- **Source Script**: `04-migration-scripts/master/form_types_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates.template_type + debrief_templates.template_type`
- **New Path**: `smac_master_migration.template.form_types`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Form Types (from debrief_templates) (`debrief_templates` → `form_types`)

## Migration Notes

- Extracts distinct template_type values from appraisal_templates and debrief_templates tables
- Generates new UUID for each distinct value
- Generates code from name using UPPER(REGEXP_REPLACE(TRIM(name), '[^A-Za-z0-9]', '_', 'g'))
- Uses name as description
- Looks up module_id from modules table (required NOT NULL field)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Master table with module dependency
- Part of form_types migration. Extracts distinct template_type values from debrief_templates table and combines with appraisal_templates using UNION. See appraisal_templates entry for full migration details.

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE template.form_types` before insert (full table reload).
- Orchestration dependencies: `modules`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | DISTINCT ON (TRIM(UPPER(combined.template_type))) gen_random_uuid() as id | DISTINCT ON (TRIM(UPPER(combined.template_type))) gen_random_uuid() |
| 2 | derived | - | code | - | UPPER(REGEXP_REPLACE(TRIM(combined.template_type), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(combined.template_type), '[^A-Za-z0-9]', '_', 'g')) |
| 3 | derived | - | name | - | TRIM(combined.template_type) as name | TRIM(combined.template_type) |
| 4 | derived | - | description | - | TRIM(combined.template_type) as description | TRIM(combined.template_type) |
| 5 | derived | - | module_id | - | COALESCE((SELECT id FROM default_module LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid) as module_id | COALESCE((SELECT id FROM default_module LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | created_at | - | COALESCE(combined.created_at, NOW()) as created_at | COALESCE(combined.created_at, NOW()) |
| 10 | derived | - | updated_at | - | COALESCE(combined.updated_at, combined.created_at, NOW()) as updated_at | COALESCE(combined.updated_at, combined.created_at, NOW()) |
| 11 | derived | - | deleted_at | - | combined.deleted_at as deleted_at | combined.deleted_at |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | - | - | level | - | NULL | NULL::numeric |
| 15 | - | - | tags | - | NULL | NULL::text[] |
| 16 | derived | - | status | - | CASE WHEN combined.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN combined.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 17 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 18 | derived | - | defined_by | - | 0 as defined_by | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/form_types_migration.sql`

## Validation

- Run `05-validation/master/form_types_validation.sql` if available
- Run `06-rollback/master/form_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
