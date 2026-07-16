# Table Mapping: ml_template_form_master + ml_template_details → ml_forms_templates

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ml_template_form_master + ml_template_details
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: ml_forms_templates
- **Source Script**: `04-migration-scripts/master/ml_forms_templates_migration.sql`

- **Legacy Path**: `synergy_master.public.ml_template_form_master + ml_template_details`
- **New Path**: `smac_master_migration.crewing.ml_forms_templates`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: ML Forms Templates (`ml_template_form_master` → `ml_forms_templates`)

## Migration Notes

- Sources: JOIN `ml_template_details` + `ml_template_form_master` → `crewing.ml_forms_templates`
- Target `id` = `ml_template_details.id` preserved via `resolve_target_id()` with `p_target_id = id`
- Each template version in details becomes a separate SMAC row
- `form_number` generated: `FORM-` + zero-padded row number
- `company_id` initially `DEFAULT_TENANT_ID`; post-migration UPDATE to `companies` where `code='SMRSPL'`
- Filter: non-empty `template_name` and `code`
- `status` Case 1 from coalesced detail/master `deleted_at`

## Special Considerations

- This migration combines data from ml_template_form_master (main template) and ml_template_details (versions)
- Target id maps to ml_template_details.id (preserving legacy UUID from details table)
- Script performs `TRUNCATE TABLE crewing.ml_forms_templates` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id (details)` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `ml_template_details.id::text`; `p_target_id = id` | Pattern 4 |
| 2 | `code (master)` | text | `code` | text | `UPPER(TRIM(code))` | From form master |
| 3 | `template_name (master)` | text | `name` | text | `TRIM(template_name)` |  |
| 4 | `—` | — | `description` | text | `NULL` |  |
| 5 | `—` | — | `form_number` | text | `'FORM-' || LPAD(ROW_NUMBER() OVER (ORDER BY id), 6, '0')` | Generated |
| 6 | `—` | — | `company_id` | uuid | Initially `DEFAULT_TENANT_ID`; post-UPDATE to SMRSPL company |  |
| 7 | `detail_created_at, master_created_at` | timestamp | `date_of_revision` | date | `COALESCE(detail_created_at, master_created_at, CURRENT_DATE)::date` |  |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 9 | `version (details)` | text | `version` | integer | Cast numeric text to integer; default `1` |  |
| 10 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 13 | `detail_deleted_at, master_deleted_at` | timestamp | `status` | integer | Case 1 — any deleted_at → Deleted (3); else Active (0) |  |
| 14 | `detail_created_at, master_created_at` | timestamp | `created_at` | timestamp | `COALESCE(detail, master, NOW())` |  |
| 15 | `detail_updated_at, master_updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(detail, master, NOW())` |  |
| 16 | `detail_deleted_at, master_deleted_at` | timestamp | `deleted_at` | timestamp | `COALESCE(detail_deleted_at, master_deleted_at)` |  |
| 17 | `master_id, version` | uuid, text | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; notes include legacy master_id/version |  |

**SAC columns not migrated:** `template_id` (join key only).

**Post-migration update:** `company_id` set from `public.companies` where `code='SMRSPL'`.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/ml_forms_templates_migration.sql`

## Validation

- Run `05-validation/master/ml_forms_templates_validation.sql` if available
- Run `06-rollback/master/ml_forms_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
