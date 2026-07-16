# Table Mapping: place_of_engagements → place_of_engagements

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: place_of_engagements
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: place_of_engagements
- **Source Script**: `04-migration-scripts/master/place_of_engagements_migration.sql`

- **Legacy Path**: `synergy_master.public.place_of_engagements`
- **New Path**: `smac_master_migration.crewing.place_of_engagements`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Place of Engagements (`place_of_engagements` → `place_of_engagements`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.place_of_engagements` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, created_at, name | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'place_of_engagements'::VARCHAR(100), CASE WHEN ROW_NUMBER() OVER (PARTITION BY legacy_data.... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 4 | derived | - | country_id | - | COALESCE( st.country_id, c.id ) as country_id | COALESCE( st.country_id, c.id ) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | derived | - | level | - | 0::numeric as level | 0::numeric |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/place_of_engagements_migration.sql`

## Validation

- Run `05-validation/master/place_of_engagements_validation.sql` if available
- Run `06-rollback/master/place_of_engagements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
