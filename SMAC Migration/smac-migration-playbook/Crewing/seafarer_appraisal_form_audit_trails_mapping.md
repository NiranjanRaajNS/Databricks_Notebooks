# Table Mapping: seafarer_appraisal_forms → seafarer_appraisal_form_audit_trails

## Overview
- **Legacy Database**: smac_crewing_migration
- **Legacy Schema**: public
- **Legacy Table**: seafarer_appraisal_forms
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisal_form_audit_trails
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisal_form_audit_trails_migration.sql`

- **Legacy Path**: `smac_crewing_migration.public.seafarer_appraisal_forms`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisal_form_audit_trails`

## Business Key

- **Composite Key**: (`seafarer_id`, `form_definitions_id`)
- **Source (orchestration)**: Appraisals (`seafarer_appraisal_forms` → `seafarer_appraisal_form_audit_trails`)

## Migration Notes

- Creates audit trail records for existing appraisal forms
- Joins seafarer_other_details and seafarer_documents on seafarer_doc_id. Extracts submission_data from seafarer_documents.form_response JSONB. Maps seafarer_id via migration.table_mappings (try seafarer_uuid first, then seafarer_id). Maps is_confirmed to is_verified, verified_date to verified_at. Uses standardized SMAC audit_info structure. Only migrates records where form_response IS NOT NULL AND form_response::text <> '{}'.

## Special Considerations

- Orchestration dependencies: `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | appraisal_form_id | - | saf.id AS appraisal_form_id | saf.id |
| 3 | derived | - | action_type | - | CASE WHEN UPPER(TRIM(COALESCE(saf.form_status, ''))) = 'COMPLETED' THEN 'Submitted' ELSE 'Created' END AS action_type | CASE WHEN UPPER(TRIM(COALESCE(saf.form_status, ''))) = 'COMPLETED' THEN 'Submitted' ELSE 'Created' END |
| 4 | derived | - | action_data | - | jsonb_build_object( 'formId', saf.id::text, 'stageType', saf.stage_type, 'assignedTo', CASE WHEN saf.assigned_to_user_id IS NOT NULL THEN saf.assigned_to_user_id::text ELSE NULL... | jsonb_build_object( 'formId', saf.id::text, 'stageType', saf.stage_type, 'assignedTo', CASE WHEN saf.assigned_to_user_id IS NOT NULL THEN saf.assigned_to_user_id::text ELSE NULL... |
| 5 | derived | - | performed_by_id | - | CASE WHEN saf.audit_info IS NOT NULL AND saf.audit_info->>'created_by' IS NOT NULL AND saf.audit_info->>'created_by' <> '' AND saf.audit_info->>'created_by' ~* '^[0-9a-f]{8}-[0-... | CASE WHEN saf.audit_info IS NOT NULL AND saf.audit_info->>'created_by' IS NOT NULL AND saf.audit_info->>'created_by' <> '' AND saf.audit_info->>'created_by' ~* '^[0-9a-f]{8}-[0-... |
| 6 | derived | - | performed_at | - | NOW() AS performed_at | NOW() |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_appraisal_forms`
- `seafarer_appraisal_forms`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_appraisal_form_audit_trails_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_appraisal_form_audit_trails_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisal_form_audit_trails_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
