# Table Mapping: competency_types → competency_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_types
- **Source Script**: `04-migration-scripts/master/competency_types_migration.sql`

- **Legacy Path**: `efr.public.competency_tasks.competency_type (distinct values)`
- **New Path**: `smac_master_migration.crewing.competency_types`

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Extracts distinct competency_type values from competency_tasks table
- Script performs `TRUNCATE TABLE crewing.competency_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (UPPER(REPLACE(TRIM(competency_type), ' ', '_'))) migration.resolve_target_id( COALESCE(:'SOURCE_DB', 'efr')::VARCHAR(100), COALESCE(:'SOURCE_SCHEMA', 'public')::VAR... |
| 2 | derived | - | code | - | UPPER(REPLACE(TRIM(competency_type), ' ', '_')) as code | UPPER(REPLACE(TRIM(competency_type), ' ', '_')) |
| 3 | derived | - | name | - | TRIM(competency_type) as name | TRIM(competency_type) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 12 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 13 | competency_type | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, 'Migrated from ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/competency_types_migration.sql`

## Validation

- Run `05-validation/master/competency_types_validation.sql` if available
- Run `06-rollback/master/competency_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
