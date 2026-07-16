# Table Mapping: crane_types → cranes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: crane_types
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: cranes
- **Source Script**: `04-migration-scripts/master/cranes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.crane_types`
- **New Path**: `smac_master_migration.vessel.cranes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cranes (`crane_types` → `cranes`)

## Migration Notes

- Preserves legacy identifier UUID as target id
- Generates code from name (first 15 chars, uppercase, replace spaces with underscores)
- Maps crane_type_id to "Deck cranes" ID from target vessel.cranes table
- Maps deleted_at to status (Deleted = 3 if deleted_at IS NOT NULL)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Uses migration.build_audit_info() for standardized audit_info structure
- Sets level to 0 (not NULL)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.cranes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'crane_types'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), '... |
| 2 | name | - | code | - | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')) AS code | UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')) |
| 3 | name | - | name | - | TRIM(legacy_data.name) AS name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | TRIM(legacy_data.description) AS description | TRIM(legacy_data.description) |
| 5 | derived | - | crane_type_id | - | CASE WHEN NULLIF(current_setting('migration.deck_cranes_id', true), '')::uuid IS NOT NULL THEN NULLIF(current_setting('migration.deck_cranes_id', true), '')::uuid ELSE (SELECT i... | CASE WHEN NULLIF(current_setting('migration.deck_cranes_id', true), '')::uuid IS NOT NULL THEN NULLIF(current_setting('migration.deck_cranes_id', true), '')::uuid ELSE (SELECT i... |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 9 | derived | - | version | - | 1 AS version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULLIF(legacy_data.created_by_id, '')::varchar, NULL::varchar, NULLIF(legacy_data.updated_by_id, '')::varchar, NULL::varchar, NULL::varchar, NULL::ti... |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/cranes_migration.sql`

## Validation

- Run `05-validation/master/cranes_validation.sql` if available
- Run `06-rollback/master/cranes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
