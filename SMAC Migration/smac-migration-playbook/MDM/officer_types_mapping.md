# Table Mapping: officertype → officer_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: officertype
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: officer_types
- **Source Script**: `04-migration-scripts/master/officer_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.officertype`
- **New Path**: `smac_master_migration.public.officer_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Officertype (`officertype` → `officer_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates officertype preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE public.officer_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'officertype'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'pu... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | name | - | level | - | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name) ASC) - 1 as level | ROW_NUMBER() OVER (ORDER BY TRIM(legacy_data.name) ASC) - 1 |
| 12 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 13 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 15 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | name, identifier | - | tags | - | generate_meaningful_code() | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) AS tag UNION ALL SELECT LOWER(REPLACE(... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/officer_types_migration.sql`

## Validation

- Run `05-validation/master/officer_types_validation.sql` if available
- Run `06-rollback/master/officer_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
