# Table Mapping: vessel_particulars → capacity

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_particulars
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: capacity
- **Source Script**: `04-migration-scripts/master/capacity_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_particulars`
- **New Path**: `smac_master_migration.vessel.capacity`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Capacity Types (`vessel_particulars` → `capacity`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Skipping duplicate UUID check - source is column names from information_schema (not a table with UUID column)
- Special transformation: Extract columns ending with '_capacity' from vessel_particulars. Creates one row per capacity column in vessel.capacity. This migration creates reference/master data from column names, not actual data values. Each capacity type gets a unique code, name (uppercase with spaces), and tags array. Only fuel_oil_capacity is marked as mandatory.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.capacity` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_particulars'::VARCHAR(100), cd.column_name::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(cd.name, NULL) |
| 3 | derived | - | name | - | cd.name | cd.name |
| 4 | derived | - | description | - | cd.description | cd.description |
| 5 | derived | - | default_uom_id | - | NULL AS default_uom_id | NULL |
| 6 | derived | - | is_mandatory | - | cd.is_mandatory | cd.is_mandatory |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 9 | derived | - | version | - | 1 AS version | 1 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NULL AS updated_at | NULL |
| 12 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 13 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 14 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 15 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 16 | derived | - | tags | - | ARRAY[ CASE WHEN cd.column_name = 'ballistic_capacity' THEN 'ballast_capacity' ELSE cd.column_name END ] AS tags | ARRAY[ CASE WHEN cd.column_name = 'ballistic_capacity' THEN 'ballast_capacity' ELSE cd.column_name END ] |
| 17 | - | - | status | - | DEFAULT_STATUS | CASE WHEN cd.name IN ('Feu Capacity', 'Fresh Water Capacity', 'Lifeboat Capacity', 'Lifeboat Capacity Without Gear', 'Lubricating Oil Capacity') THEN 3 ELSE :'DEFAULT_STATUS'::i... |
| 18 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 19 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/capacity_migration.sql`

## Validation

- Run `05-validation/master/capacity_validation.sql` if available
- Run `06-rollback/master/capacity_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
