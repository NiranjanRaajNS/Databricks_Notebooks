# Table Mapping: relief_reasons → relief_reasons

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: relief_reasons
- **Source Script**: `04-migration-scripts/master/relief_reasons_migration.sql`

- **Legacy Path**: `synergy_manning.public.reliefs.reason`
- **New Path**: `smac_master_migration.crewing.relief_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Relief Reasons (`reliefs` → `relief_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Extracts distinct reason values from reliefs.reason column

## Special Considerations

- Extracts distinct reason values from reliefs table
- Script performs `TRUNCATE TABLE crewing.relief_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | reason | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'relief_reasons'::VARCHAR(100), LEFT(COALESCE(InitCap(TRIM(legacy_data.reason)), 'UNKNOWN')... |
| 2 | reason | - | code | - | generate_meaningful_code() | generate_meaningful_code(InitCap(TRIM(legacy_data.reason)), NULL) |
| 3 | reason | - | name | - | LEFT(InitCap(TRIM(legacy_data.reason)), 100)::varchar(100) as name | LEFT(InitCap(TRIM(legacy_data.reason)), 100)::varchar(100) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | level | - | 0 as level | 0 |
| 9 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 2 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 2 ELSE 0 END |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/relief_reasons_migration.sql`

## Validation

- Run `05-validation/master/relief_reasons_validation.sql` if available
- Run `06-rollback/master/relief_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
