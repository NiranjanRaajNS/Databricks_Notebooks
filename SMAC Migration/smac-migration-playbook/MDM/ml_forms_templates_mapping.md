# Table Mapping: ml_template_form_master + ml_template_details → ml_forms_templates

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ml_template_form_master + ml_template_details
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: ml_forms_templates
- **Migration Script**: `04-migration-scripts/master/ml_forms_templates_migration.sql`

- **Legacy Path**: `synergy_master.public.ml_template_form_master + ml_template_details`
- **New Path**: `smac_master_migration.crewing.ml_forms_templates`

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (combined_data.id) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ml_template_details'::VARCHAR(100), combined_data.id::text, ... |
| 2 | derived | - | code | - | UPPER(TRIM(combined_data.code)) as code | UPPER(TRIM(combined_data.code)) |
| 3 | derived | - | name | - | TRIM(combined_data.template_name) as name | TRIM(combined_data.template_name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | form_number | - | 'FORM-' || LPAD(ROW_NUMBER() OVER (ORDER BY combined_data.id)::text, 6, '0') as form_number | 'FORM-' || LPAD(ROW_NUMBER() OVER (ORDER BY combined_data.id)::text, 6, '0') |
| 6 | - | - | company_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | date_of_revision | - | COALESCE(combined_data.detail_created_at::date, combined_data.master_created_at::date, CURRENT_DATE) as date_of_revision | COALESCE(combined_data.detail_created_at::date, combined_data.master_created_at::date, CURRENT_DATE) |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | version | - | COALESCE( CASE WHEN combined_data.version ~ '^[0-9]+$' THEN combined_data.version::integer ELSE NULL END, 1 ) as version | COALESCE( CASE WHEN combined_data.version ~ '^[0-9]+$' THEN combined_data.version::integer ELSE NULL END, 1 ) |
| 10 | derived | - | level | - | 0 as level | 0 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | derived | - | status | - | CASE WHEN COALESCE(combined_data.detail_deleted_at, combined_data.master_deleted_at) IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN COALESCE(combined_data.detail_deleted_at, combined_data.master_deleted_at) IS NOT NULL THEN 3 ELSE 0 END |
| 14 | derived | - | created_at | - | COALESCE(combined_data.detail_created_at, combined_data.master_created_at, NOW()) as created_at | COALESCE(combined_data.detail_created_at, combined_data.master_created_at, NOW()) |
| 15 | derived | - | updated_at | - | COALESCE(combined_data.detail_updated_at, combined_data.master_updated_at, NOW()) as updated_at | COALESCE(combined_data.detail_updated_at, combined_data.master_updated_at, NOW()) |
| 16 | derived | - | deleted_at | - | COALESCE(combined_data.detail_deleted_at, combined_data.master_deleted_at) as deleted_at | COALESCE(combined_data.detail_deleted_at, combined_data.master_deleted_at) |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from migration script)

- See migration script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the migration script. Refer to:
- `04-migration-scripts/master/ml_forms_templates_migration.sql`

## Validation

- Run `05-validation/master/ml_forms_templates_validation.sql` if available
- Run `06-rollback/master/ml_forms_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration script. Review complex multi-INSERT or unpivot migrations manually.
