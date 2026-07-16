# Table Mapping: fdl_department → fdl_departments

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: fdl_department
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_departments
- **Source Script**: `04-migration-scripts/master/fdl_departments_migration.sql`

- **Legacy Path**: `synergy_vessel.public.fdl_department`
- **New Path**: `smac_master_migration.vessel.fdl_departments`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- TRUNCATE public.departments then copy from smac_master_migration.public.departments (dblink). Clears migration.table_mappings for departments/Department. Preserves UUIDs for FK alignment with designations from master.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_departments` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'fdl_department'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(COALESCE(legacy_data.name, 'UNKNOWN')), TRIM(COALESCE(legacy_data.name, 'UNKNOWN'))) |
| 3 | display_name, name | - | name | - | LEFT(COALESCE(legacy_data.display_name, legacy_data.name), 255) AS name | LEFT(COALESCE(legacy_data.display_name, legacy_data.name), 255) |
| 4 | display_name | - | description | - | CASE WHEN legacy_data.display_name IS NULL THEN NULL WHEN TRIM(legacy_data.display_name) = '' THEN NULL ELSE TRIM(legacy_data.display_name) END AS description | CASE WHEN legacy_data.display_name IS NULL THEN NULL WHEN TRIM(legacy_data.display_name) = '' THEN NULL ELSE TRIM(legacy_data.display_name) END |
| 5 | derived | - | service_type_id | - | st.id AS service_type_id | st.id |
| 6 | derived | - | scope | - | 0 AS scope | 0 |
| 7 | derived | - | is_multi_cluster | - | CASE WHEN st.name = 'Crewing' THEN true ELSE false END AS is_multi_cluster | CASE WHEN st.name = 'Crewing' THEN true ELSE false END |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | display_order | - | level | - | COALESCE(legacy_data.display_order, 0) AS level | COALESCE(legacy_data.display_order, 0) |
| 11 | derived | - | version | - | 1 AS version | 1 |
| 12 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 13 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 14 | status | - | status | - | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'INAC... | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'INAC... |
| 15 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 16 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 17 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 18 | - | - | archived_at | - | NULL | NULL::timestamp |
| 19 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 20 | name, display_name | - | tags | - | generate_meaningful_code() | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT LOWER(generate_meaningful_code(TRIM(COALESCE(legacy_data.name, 'UNKNOWN')), TRIM(COALESCE(legacy_data.name, 'UNKNOWN'... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/fdl_departments_migration.sql`

## Validation

- Run `05-validation/master/fdl_departments_validation.sql` if available
- Run `06-rollback/master/fdl_departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
