# Table Mapping: vessel_charterer_details (distinct charterer_type) → charterer_types

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_charterer_details (distinct charterer_type)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: charterer_types
- **Source Script**: `04-migration-scripts/master/charterer_types_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_charterer_details (distinct charterer_type)`
- **New Path**: `smac_master_migration.vessel.charterer_types`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Vessel Charterer Details (`vessel_charterer_details` → `charterer_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Check for duplicate UUIDs in source table
- Migrates distinct charterer_type values from vessel_charterer_details to charterer_types. Must be migrated before vessel_charterers.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.charterer_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | charterer_type | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_charterer_details'::VARCHAR(100), LEFT(TRIM(legacy_data.charterer_type), 100)::text,... |
| 2 | charterer_type | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.charterer_type), gen_random_uuid()::text) |
| 3 | charterer_type | - | name | - | TRIM(legacy_data.charterer_type) as name | TRIM(legacy_data.charterer_type) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 as status | 0 |
| 9 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 11 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/charterer_types_migration.sql`

## Validation

- Run `05-validation/master/charterer_types_validation.sql` if available
- Run `06-rollback/master/charterer_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
