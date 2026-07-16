# Table Mapping: vdr_make → vdr_makes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vdr_make
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vdr_makes
- **Source Script**: `04-migration-scripts/master/vdr_makes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vdr_make`
- **New Path**: `smac_master_migration.vessel.vdr_makes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vdr Make (`vdr_make` → `vdr_makes`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vdr_makes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.identifier) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vdr_make'::VARCHAR(100), legacy_data.identifier::text,... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(COALESCE(TRIM(legacy_data.name), 'UNKNOWN'), legacy_data.identifier::text) |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') AS name | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 11 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vdr_makes_migration.sql`

## Validation

- Run `05-validation/master/vdr_makes_validation.sql` if available
- Run `06-rollback/master/vdr_makes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
