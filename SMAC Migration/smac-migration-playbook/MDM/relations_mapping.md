# Table Mapping: family_relations → relations

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: family_relations
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: relations
- **Source Script**: `04-migration-scripts/master/relations_migration.sql`

- **Legacy Path**: `synergy_master.public.family_relations`
- **New Path**: `smac_master_migration.public.relations`

## Migration Notes

- Preserve legacy uuid (UUID) as id if available, otherwise generate new UUID
- Uses migration.resolve_target_id() for idempotent UUID generation
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.relations` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'family_relations'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | relation | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.relation)) |
| 3 | relation | - | name | - | TRIM(legacy_data.relation) as name | TRIM(legacy_data.relation) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/relations_migration.sql`

## Validation

- Run `05-validation/master/relations_validation.sql` if available
- Run `06-rollback/master/relations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
