# Table Mapping: availability_remarks → availability_remarks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: availability_remarks
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: availability_remarks
- **Source Script**: `04-migration-scripts/master/availability_remarks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.availability_remarks`
- **New Path**: `smac_master_migration.crewing.availability_remarks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Availability Remarks (`availability_remarks` → `availability_remarks`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- availability_remarks source table has id (bigint) but no uuid/identifier column

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.availability_remarks` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'availability_remarks'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | description | - | COALESCE(TRIM(description), '') as description | COALESCE(TRIM(description), '') |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | CASE WHEN deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 12 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 13 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 14 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 15 | derived | - | tags | - | generate_meaningful_code() | CASE WHEN LOWER(generate_meaningful_code(TRIM(name), NULL)) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(name), ' ', '_'), '-', '_'), '/', '_'), '.', '_')) THEN ARRAY[ LOWER(ge... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/availability_remarks_migration.sql`

## Validation

- Run `05-validation/master/availability_remarks_validation.sql` if available
- Run `06-rollback/master/availability_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
