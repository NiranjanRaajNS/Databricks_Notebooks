# Table Mapping: departure_checklists → departure_checklist

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: departure_checklists
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: departure_checklist
- **Source Script**: `04-migration-scripts/master/departure_checklist_migration.sql`

- **Legacy Path**: `synergy_manning.public.departure_checklists`
- **New Path**: `smac_master_migration.crewing.departure_checklist`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Departure Checklist (`departure_checklists` → `departure_checklist`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates departure_checklists from synergy_manning.public.departure_checklists to smac_master_migration.crewing.departure_checklist. Uses idempotent UUID resolution via migration.resolve_target_id() since source table has no UUID column. Status mapping based on deleted_at (Case 1 pattern).

## Special Considerations

- Run 01-discovery/master/inspect_departure_checklists_schema.sql FIRST to verify schema
- Script performs `TRUNCATE TABLE crewing.departure_checklist` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'departure_checklists'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCH... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | - | - | parent_id | - | NULL | NULL::uuid |
| 6 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 16 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/departure_checklist_migration.sql`

## Validation

- Run `05-validation/master/departure_checklist_validation.sql` if available
- Run `06-rollback/master/departure_checklist_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
