# Table Mapping: vessel_groups → company_wage_groups

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_groups
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_groups
- **Source Script**: `04-migration-scripts/master/company_wage_groups_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_groups`
- **New Path**: `smac_master_migration.crewing.company_wage_groups`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Groups (`vessel_groups` → `company_wage_groups`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_groups from synergy_vessel.public.vessel_groups. Preserves identifier/uuid when available.

## Special Considerations

- Source table has identifier column - preserve legacy UUID when available
- Script performs `TRUNCATE TABLE crewing.company_wage_groups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_groups'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 4 | derived | - | description | - | '' as description | '' |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | status, deleted_at | - | status | - | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |
| 14 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/company_wage_groups_migration.sql`

## Validation

- Run `05-validation/master/company_wage_groups_validation.sql` if available
- Run `06-rollback/master/company_wage_groups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
