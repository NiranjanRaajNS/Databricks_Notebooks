# Table Mapping: disciplinary_reasons → disciplinary_reasons

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: disciplinary_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: disciplinary_reasons
- **Source Script**: `04-migration-scripts/master/disciplinary_reasons_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.disciplinary_reasons`
- **New Path**: `smac_master_migration.crewing.disciplinary_reasons`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Disciplinary Reasons (`disciplinary_reasons` → `disciplinary_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates disciplinary_reasons preserving legacy UUID id

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.disciplinary_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'disciplinary_reasons'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | name | - | code | - | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')) AS code | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | COALESCE(NULLIF(TRIM(legacy_data.description), ''), '') as description | COALESCE(NULLIF(TRIM(legacy_data.description), ''), '') |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) <> '' THEN TRIM(legacy_data.created_by_id) ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/disciplinary_reasons_migration.sql`

## Validation

- Run `05-validation/master/disciplinary_reasons_validation.sql` if available
- Run `06-rollback/master/disciplinary_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
