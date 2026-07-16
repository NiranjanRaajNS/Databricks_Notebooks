# Table Mapping: rank_type → rank_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: rank_type
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: rank_types
- **Source Script**: `04-migration-scripts/master/rank_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.rank_type`
- **New Path**: `smac_master_migration.public.rank_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Rank Type (`rank_type` → `rank_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_type preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'rank_type'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'publ... |
| 2 | rank_type_name | - | code | - | CASE WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'SUPPORT' THEN 'SUP' WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'OPERATIONS' OR UPPER(TRIM(legacy_data.rank_type_name)) =... | CASE WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'SUPPORT' THEN 'SUP' WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'OPERATIONS' OR UPPER(TRIM(legacy_data.rank_type_name)) =... |
| 3 | rank_type_name | - | name | - | COALESCE(legacy_data.rank_type_name, 'UNKNOWN') AS name | COALESCE(legacy_data.rank_type_name, 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | level | - | 0 AS level | 0 |
| 10 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 13 | rank_type_name | - | tags | - | CASE WHEN LOWER(COALESCE(TRIM( CASE WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'SUPPORT' THEN 'SUP' WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'OPERATIONS' OR UPPER(TRIM... | CASE WHEN LOWER(COALESCE(TRIM( CASE WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'SUPPORT' THEN 'SUP' WHEN UPPER(TRIM(legacy_data.rank_type_name)) = 'OPERATIONS' OR UPPER(TRIM... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/rank_types_migration.sql`

## Validation

- Run `05-validation/master/rank_types_validation.sql` if available
- Run `06-rollback/master/rank_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
