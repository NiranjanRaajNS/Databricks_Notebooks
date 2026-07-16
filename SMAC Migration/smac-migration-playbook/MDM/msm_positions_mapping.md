# Table Mapping: msm_positions → msm_positions

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: msm_positions
- **Source Script**: `04-migration-scripts/master/msm_positions_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks.msm_position`
- **New Path**: `smac_master_migration.public.msm_positions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Positions (`positions` → `positions`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Duplicate UUID check is not applicable for msm_positions

## Special Considerations

- Script performs `TRUNCATE TABLE public.msm_positions` before insert (full table reload).
- Orchestration dependencies: `ranks`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | msm_position | - | id | - | migration.resolve_target_id() | DISTINCT ON (TRIM(UPPER(legacy_data.msm_position))) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ranks'::VARCHAR(100), TRIM(UPPER(legacy... |
| 2 | msm_position | - | name | - | TRIM(legacy_data.msm_position) as name | TRIM(legacy_data.msm_position) |
| 3 | msm_position | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.msm_position), NULL) |
| 4 | msm_position | - | description | - | TRIM(legacy_data.msm_position) as description | TRIM(legacy_data.msm_position) |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | - | - | tags | - | NULL | NULL::text[] |
| 15 | derived | - | status | - | 0 as status | 0 |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/msm_positions_migration.sql`

## Validation

- Run `05-validation/master/msm_positions_validation.sql` if available
- Run `06-rollback/master/msm_positions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
