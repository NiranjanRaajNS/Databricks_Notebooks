# Table Mapping: vaccines → vaccines

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vaccines
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: vaccines
- **Source Script**: `04-migration-scripts/master/vaccines_migration.sql`

- **Legacy Path**: `synergy_master.public.vaccines`
- **New Path**: `smac_master_migration.crewing.vaccines`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vaccines (`vaccines` → `vaccines`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.vaccines` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'vaccines'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'cre... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | vaccine_type | - | TRIM(vaccine_type) as vaccine_type | TRIM(vaccine_type) |
| 5 | derived | - | level | - | CASE WHEN TRIM(position) ~ '^-?[0-9]+\.?[0-9]*$' THEN TRIM(position)::numeric WHEN TRIM(position) = '' THEN NULL ELSE NULL END as level | CASE WHEN TRIM(position) ~ '^-?[0-9]+\.?[0-9]*$' THEN TRIM(position)::numeric WHEN TRIM(position) = '' THEN NULL ELSE NULL END |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vaccines_migration.sql`

## Validation

- Run `05-validation/master/vaccines_validation.sql` if available
- Run `06-rollback/master/vaccines_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
