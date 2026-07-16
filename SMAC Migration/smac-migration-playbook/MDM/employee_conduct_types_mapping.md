# Table Mapping: conduct → employee_conduct_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: conduct
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: employee_conduct_types
- **Source Script**: `04-migration-scripts/master/employee_conduct_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.conduct`
- **New Path**: `smac_master_migration.crewing.employee_conduct_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Conduct (`conduct` → `employee_conduct_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates conduct preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.employee_conduct_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'conduct'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'crewin... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 as status | 0 |
| 9 | derived | - | level | - | 0 as level | 0 |
| 10 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/employee_conduct_types_migration.sql`

## Validation

- Run `05-validation/master/employee_conduct_types_validation.sql` if available
- Run `06-rollback/master/employee_conduct_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
