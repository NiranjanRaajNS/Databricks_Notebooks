# Table Mapping: ml_template_form_master + ml_template_details → ml_forms_templates

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ml_template_form_master + ml_template_details
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: ml_forms_templates
- **Source Script**: `04-migration-scripts/crewing/ml_forms_templates_migration.sql`

- **Legacy Path**: `synergy_master.public.ml_template_form_master + ml_template_details`
- **New Path**: `smac_master_migration.crewing.ml_forms_templates`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: ML Forms Templates (`ml_template_form_master` → `ml_forms_templates`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates ml_template_form_master to ml_forms_templates table. Combines data from ml_template_form_master and ml_template_details. Preserves legacy UUID id when available. Each template version in ml_template_details becomes a separate record. Generates form_number, sets default values for tenant_id, version, defined_by, workflow_status, and status.

## Special Considerations

- This migration combines data from ml_template_form_master (main template) and ml_template_details (versions)
- Target id maps to ml_template_details.id (preserving legacy UUID from details table)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | COALESCE(combined_data.id, gen_random_uuid()) as id | COALESCE(combined_data.id, gen_random_uuid()) |
| 2 | derived | - | code | - | TRIM(combined_data.code) as code | TRIM(combined_data.code) |
| 3 | derived | - | name | - | TRIM(combined_data.template_name) as name | TRIM(combined_data.template_name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | form_number | - | 'FORM-' || LPAD(ROW_NUMBER() OVER (ORDER BY combined_data.id)::text, 6, '0') as form_number | 'FORM-' || LPAD(ROW_NUMBER() OVER (ORDER BY combined_data.id)::text, 6, '0') |
| 6 | derived | - | company_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as company_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 7 | derived | - | date_of_revision | - | COALESCE(combined_data.detail_created_at::date, combined_data.master_created_at::date, CURRENT_DATE) as date_of_revision | COALESCE(combined_data.detail_created_at::date, combined_data.master_created_at::date, CURRENT_DATE) |
| 8 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 9 | derived | - | version | - | COALESCE( CASE WHEN combined_data.version ~ '^[0-9]+$' THEN combined_data.version::integer ELSE NULL END, 1 ) as version | COALESCE( CASE WHEN combined_data.version ~ '^[0-9]+$' THEN combined_data.version::integer ELSE NULL END, 1 ) |
| 10 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 11 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 12 | derived | - | status | - | 0 as status | 0 |
| 13 | derived | - | created_at | - | COALESCE(combined_data.detail_created_at, combined_data.master_created_at, NOW()) as created_at | COALESCE(combined_data.detail_created_at, combined_data.master_created_at, NOW()) |
| 14 | derived | - | updated_at | - | COALESCE(combined_data.detail_updated_at, combined_data.master_updated_at, NOW()) as updated_at | COALESCE(combined_data.detail_updated_at, combined_data.master_updated_at, NOW()) |
| 15 | derived | - | audit_info | - | jsonb_build_object( 'legacy_detail_id', combined_data.id::text, 'legacy_master_id', combined_data.master_id::text, 'legacy_version', combined_data.version, 'migrated_at', NOW(),... | jsonb_build_object( 'legacy_detail_id', combined_data.id::text, 'legacy_master_id', combined_data.master_id::text, 'legacy_version', combined_data.version, 'migrated_at', NOW(),... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/ml_forms_templates_migration.sql`

## Validation

- Run `05-validation/crewing/ml_forms_templates_validation.sql` if available
- Run `06-rollback/crewing/ml_forms_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
