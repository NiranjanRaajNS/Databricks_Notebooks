# Table Mapping: reason_for_debrief → debriefing_reasons

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: reason_for_debrief
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: debriefing_reasons
- **Source Script**: `04-migration-scripts/master/debriefing_reasons_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.reason_for_debrief`
- **New Path**: `smac_master_migration.crewing.debriefing_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Debriefing Reasons (`reason_for_debrief` → `debriefing_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates reason_for_debrief from synergy_seafarer.public.reason_for_debrief to smac_master_migration.crewing.debriefing_reasons. Preserves legacy UUID (id) as target id using migration.resolve_target_id(). Generates code from name using UPPER(REPLACE(TRIM(name), ' ', '_')). Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Sets default values: category=1, requires_appraisal_link=false, level=1, version=1, defined_by=1, workflow_status=2. Sets tags to ARRAY['DEBRIEF']. Uses standardized SMAC audit_info structure. This is a master/reference table that must be migrated before seafarer_debriefs.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.debriefing_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'reason_for_debrief'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | name | - | code | - | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) as code | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | derived | - | category | - | 1 as category | 1 |
| 6 | derived | - | requires_appraisal_link | - | false as requires_appraisal_link | false |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | level | - | 1 as level | 1 |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | derived | - | defined_by | - | 1 as defined_by | 1 |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 17 | - | - | archived_at | - | NULL | NULL::timestamp |
| 18 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |
| 19 | derived | - | tags | - | ARRAY['DEBRIEF']::text[] as tags | ARRAY['DEBRIEF']::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/debriefing_reasons_migration.sql`

## Validation

- Run `05-validation/master/debriefing_reasons_validation.sql` if available
- Run `06-rollback/master/debriefing_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
