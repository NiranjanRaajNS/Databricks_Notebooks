# Table Mapping: vessel_pools → vessel_pools

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_pools
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_pools
- **Source Script**: `04-migration-scripts/master/vessel_pools_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_pools`
- **New Path**: `smac_master_migration.vessel.vessel_pools`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Vessel Pools (`vessel_pools` → `vessel_pools`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_pools from synergy_master.public.vessel_pools to smac_master_migration.vessel.vessel_pools. Preserves legacy UUID as target id (Pattern A). Maps boolean status to integer status (false=0 Active, false=2 Inactive) and also copies to pool_status boolean field. Stores created_by_id, updated_by_id, deleted_by_id in audit_info JSONB. Uses standardized SMAC audit_info structure without legacy_id (since UUID is preserved). No foreign key dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_pools` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_pools'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), ... |
| 2 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 3 | derived | - | description | - | TRIM(description) as description | TRIM(description) |
| 4 | derived | - | pool_status | - | COALESCE(status, true) as pool_status | COALESCE(status, true) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN legacy_data.status = true OR legacy_data.status::text = 'true' THEN 0 WHEN legacy... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN legacy_data.status = true OR legacy_data.status::text = 'true' THEN 0 WHEN legacy... |
| 12 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 14 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | created_by_id, deleted_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL THEN legacy_data.created_by_id::varchar ELSE NULL END, CASE WHEN legacy_data.deleted_by_id IS NOT NUL... |
| 17 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_pools_migration.sql`

## Validation

- Run `05-validation/master/vessel_pools_validation.sql` if available
- Run `06-rollback/master/vessel_pools_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
