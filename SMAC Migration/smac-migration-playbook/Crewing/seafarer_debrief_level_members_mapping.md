# Table Mapping: appraisal_debrief → seafarer_debrief_level_members

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_debrief
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_debrief_level_members
- **Source Script**: `04-migration-scripts/crewing/seafarer_debrief_level_members_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_debrief`
- **New Path**: `smac_crewing_migration.shore.seafarer_debrief_level_members`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debriefs (`seafarer_debrief_levels` → `seafarer_debrief_level_members`)

## Migration Notes

- Migrates appraisal_debrief to seafarer_debriefs table. Preserves legacy UUID id directly. Maps seafarer_uuid (uuid) to seafarer_id (uuid) via migration.table_mappings. Maps vessel_uuid (uuid) to vessel_id (uuid) via migration.table_mappings from smac_master_migration. Maps vessel_category_id (bigint) to vessel_type_id (uuid) via migration.table_mappings from smac_master_migration. Converts attachments (text[]) to jsonb. Maps debrief_status to both current_stage and status. Conditional mapping for closed_by/closed_at based on debrief_status. Requires seafarers, vessels, and vessel_types tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_debrief_level_members` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `vessel_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | DISTINCT ON (sdl.id, db.value->>'debriefer_id') gen_random_uuid() as id | DISTINCT ON (sdl.id, db.value->>'debriefer_id') gen_random_uuid() |
| 2 | derived | - | debrief_level_id | - | sdl.id as debrief_level_id | sdl.id |
| 3 | derived | - | user_id | - | CASE WHEN db.value->>'debriefer_id' IS NOT NULL AND db.value->>'debriefer_id' != '' THEN CASE WHEN db.value->>'debriefer_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-... | CASE WHEN db.value->>'debriefer_id' IS NOT NULL AND db.value->>'debriefer_id' != '' THEN CASE WHEN db.value->>'debriefer_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-... |
| 4 | derived | - | assigned_to_user_type | - | CASE WHEN db.value->>'role_name' IS NOT NULL AND db.value->>'role_name' != '' THEN TRIM(db.value->>'role_name') ELSE 'Shore' END as assigned_to_user_type | CASE WHEN db.value->>'role_name' IS NOT NULL AND db.value->>'role_name' != '' THEN TRIM(db.value->>'role_name') ELSE 'Shore' END |
| 5 | - | - | assigned_to_position_id | - | NULL | NULL::uuid |
| 6 | derived | - | is_primary_reviewer | - | true as is_primary_reviewer | true |
| 7 | derived | - | review_status | - | CASE WHEN fb.value->>'status' IS NOT NULL AND fb.value->>'status' != '' THEN CASE WHEN UPPER(TRIM(fb.value->>'status')) = 'COMPLETED' THEN 'Completed' WHEN UPPER(TRIM(fb.value->... | CASE WHEN fb.value->>'status' IS NOT NULL AND fb.value->>'status' != '' THEN CASE WHEN UPPER(TRIM(fb.value->>'status')) = 'COMPLETED' THEN 'Completed' WHEN UPPER(TRIM(fb.value->... |
| 8 | derived | - | remarks | - | CASE WHEN db.value->>'remarks' IS NOT NULL AND db.value->>'remarks' != '' THEN TRIM(db.value->>'remarks') ELSE NULL END as remarks | CASE WHEN db.value->>'remarks' IS NOT NULL AND db.value->>'remarks' != '' THEN TRIM(db.value->>'remarks') ELSE NULL END |
| 9 | derived | - | reviewed_at | - | CASE WHEN fb.value->>'responded_at' IS NOT NULL AND fb.value->>'responded_at' != '' THEN CASE WHEN fb.value->>'responded_at' ~ '^\d{2}/\d{2}/\d{4}' THEN TO_TIMESTAMP(fb.value->>... | CASE WHEN fb.value->>'responded_at' IS NOT NULL AND fb.value->>'responded_at' != '' THEN CASE WHEN fb.value->>'responded_at' ~ '^\d{2}/\d{2}/\d{4}' THEN TO_TIMESTAMP(fb.value->>... |
| 10 | derived | - | reviewed_by | - | CASE WHEN db.value->>'debriefer_id' IS NOT NULL AND db.value->>'debriefer_id' != '' THEN CASE WHEN db.value->>'debriefer_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-... | CASE WHEN db.value->>'debriefer_id' IS NOT NULL AND db.value->>'debriefer_id' != '' THEN CASE WHEN db.value->>'debriefer_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-... |
| 11 | derived | - | email_send | - | CASE WHEN db.value->>'is_mail_send' IS NOT NULL THEN CASE WHEN LOWER(TRIM(db.value->>'is_mail_send')) IN ('true', '1', 'yes') THEN true ELSE false END ELSE true END as email_send | CASE WHEN db.value->>'is_mail_send' IS NOT NULL THEN CASE WHEN LOWER(TRIM(db.value->>'is_mail_send')) IN ('true', '1', 'yes') THEN true ELSE false END ELSE true END |
| 12 | debrief_status | - | status | - | CASE WHEN legacy_data.debrief_status IS NOT NULL AND legacy_data.debrief_status != '' THEN CASE WHEN UPPER(TRIM(legacy_data.debrief_status)) = 'ACTIVE' THEN 'Active' WHEN UPPER(... | CASE WHEN legacy_data.debrief_status IS NOT NULL AND legacy_data.debrief_status != '' THEN CASE WHEN UPPER(TRIM(legacy_data.debrief_status)) = 'ACTIVE' THEN 'Active' WHEN UPPER(... |
| 13 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 18 | created_by_id, deleted_by, updated_by_id, id | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_debrief_levels`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_debrief_level_members_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debrief_level_members_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debrief_level_members_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
