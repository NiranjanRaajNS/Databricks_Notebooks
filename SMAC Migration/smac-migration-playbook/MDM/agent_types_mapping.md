# Table Mapping: agent_types → agent_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: agent_types
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: agent_types
- **Source Script**: `04-migration-scripts/master/agent_types_migration.sql`

- **Legacy Path**: `synergy_master.public.agent_types`
- **New Path**: `smac_master_migration.public.agent_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Agent Types (`agent_types` → `agent_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.agent_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'agent_types'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), '... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), TRIM(identifier)) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | derived | - | level | - | 0 as level | 0 |
| 11 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | name, identifier | - | tags | - | generate_meaningful_code() | CASE WHEN LOWER(TRIM(COALESCE(generate_meaningful_code(TRIM(legacy_data.name), TRIM(legacy_data.identifier)), ''))) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/agent_types_migration.sql`

## Validation

- Run `05-validation/master/agent_types_validation.sql` if available
- Run `06-rollback/master/agent_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
