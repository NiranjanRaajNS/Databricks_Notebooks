# Table Mapping: reliefstate → relief_states

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: reliefstate
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: relief_states
- **Source Script**: `04-migration-scripts/master/relief_states_migration.sql`

- **Legacy Path**: `synergy_master.enum.reliefstate`
- **New Path**: `smac_master_migration.crewing.relief_states`

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.relief_states` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | - | id | - | legacy_data.identifier as id | legacy_data.identifier |
| 2 | name | - | code | - | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 10), ' ', '_')) AS code | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 10), ' ', '_')) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 12 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/relief_states_migration.sql`

## Validation

- Run `05-validation/master/relief_states_validation.sql` if available
- Run `06-rollback/master/relief_states_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
