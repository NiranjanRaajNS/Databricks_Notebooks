# Table Mapping: bloodgroups → bloodgroups

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: bloodgroups
- **Source Script**: `04-migration-scripts/master/bloodgroups_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarers.blood_group (distinct values)`
- **New Path**: `smac_master_migration.public.bloodgroups`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Bloodgroups (`seafarers` → `bloodgroups`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Distinct values from seafarers.blood_group

## Special Considerations

- Script performs `TRUNCATE TABLE public.bloodgroups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarers'::VARCHAR(100), canonical.blood_group::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | code | - | canonical.blood_group AS code | canonical.blood_group |
| 3 | derived | - | name | - | canonical.blood_group AS name | canonical.blood_group |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | derived | - | level | - | ROW_NUMBER() OVER (ORDER BY canonical.blood_group) AS level | ROW_NUMBER() OVER (ORDER BY canonical.blood_group) |
| 11 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 12 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/bloodgroups_migration.sql`

## Validation

- Run `05-validation/master/bloodgroups_validation.sql` if available
- Run `06-rollback/master/bloodgroups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
