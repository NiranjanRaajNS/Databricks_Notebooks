# Table Mapping: sign_off_task_details → sign_off_task_details

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: sign_off_task_details
- **Source Script**: `04-migration-scripts/master/sign_off_task_details_migration.sql`

- **Legacy Path**: `smac_crewing_migration.public.sign_off_details (joined with smac_crewing_migration.public.seafarer_appraisals)`
- **New Path**: `smac_master_migration.public.sign_off_task_details`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Sign Off Task Details (`signoff_details` → `sign_off_task_details`)

## Migration Notes

- Source: sign_off_details table from target database (smac_crewing_migration) joined with seafarer_appraisals table
- Filter: sign_off_status = 0 AND appraisal_type IN ('Sign Off', 'Mid Term')
- Generate new UUID for id using migration.resolve_target_id()
- Uses standardized SMAC audit_info structure
- Get source row count (with join and filters)
- Check for duplicate UUIDs in source table
- Migrates signoff_details to sign_off_task_details table. Joins signoff_details with seafarer_appraisals via seafarer_vessel_assignment and contract_assignments. Filters by sign_off_status = 0 AND appraisal_type IN ('Sign Off', 'Mid Term'). Generates new UUID for id using migration.resolve_target_id(). Maps appraisal_code to task_code, appraisal_status to completion_status. Uses standardized SMAC audit_info structure. Requires signoff_details, seafarer_appraisals, seafarer_vessel_assignment, contract_assignments, and appraisal_types tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.sign_off_task_details` before insert (full table reload).
- Orchestration dependencies: `signoff_details`, `seafarer_appraisals`, `seafarer_vessel_assignments`, `contract_assignments`, `appraisal_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | sign_off_id | - | source_data.sign_off_detail_id AS sign_off_detail_id | source_data.sign_off_detail_id AS sign_off_detail_id |
| 3 | derived | - | task_code | - | 'APPRAISAL'::text AS task_code | 'APPRAISAL'::text |
| 4 | derived | - | completion_status | - | CASE WHEN UPPER(TRIM(COALESCE(source_data.appraisal_status, ''))) IN ('PENDING', 'INITIATED', 'DRAFT', 'ACTIVE') THEN 0 WHEN UPPER(TRIM(COALESCE(source_data.appraisal_status, ''... | CASE WHEN UPPER(TRIM(COALESCE(source_data.appraisal_status, ''))) IN ('PENDING', 'INITIATED', 'DRAFT', 'ACTIVE') THEN 0 WHEN UPPER(TRIM(COALESCE(source_data.appraisal_status, ''... |
| 5 | derived | - | remarks | - | source_data.notes AS remarks | source_data.notes |
| 6 | - | - | skip_reason_id | - | NULL | NULL::uuid |
| 7 | - | - | skip_remarks | - | NULL | NULL::text |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | status | - | CASE WHEN source_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN source_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | derived | - | created_at | - | COALESCE(source_data.created_at, NOW()) as created_at | COALESCE(source_data.created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(source_data.updated_at, NOW()) as updated_at | COALESCE(source_data.updated_at, NOW()) |
| 12 | derived | - | deleted_at | - | source_data.deleted_at as deleted_at | source_data.deleted_at |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | ( migration.build_audit_info( source_data.created_by_id::varchar, NULL::varchar, source_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/sign_off_task_details_migration.sql`

## Validation

- Run `05-validation/master/sign_off_task_details_validation.sql` if available
- Run `06-rollback/master/sign_off_task_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
