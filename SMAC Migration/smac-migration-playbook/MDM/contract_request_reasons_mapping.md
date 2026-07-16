# Table Mapping: contract_request_reasons → contract_request_reasons

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: contract_request_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: contract_request_reasons
- **Source Script**: `04-migration-scripts/master/contract_request_reasons_migration.sql`

- **Legacy Path**: `synergy_master.public.contract_request_reasons`
- **New Path**: `smac_master_migration.crewing.contract_request_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Contract Request Reasons (`contract_request_reasons` → `contract_request_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.contract_request_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_request_reasons'::VARCHAR(100), legacy_data.id::text, current_database()::text::VA... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, NULL) |
| 3 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 4 | derived | - | request_type | - | TRIM(request_type) as request_type | TRIM(request_type) |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 12 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 14 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN... |
| 15 | name | - | tags | - | generate_meaningful_code() | CASE WHEN TRIM(legacy_data.name) = 'Promotion/Change in rank' THEN ARRAY[ generate_meaningful_code(legacy_data.name, NULL) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/contract_request_reasons_migration.sql`

## Validation

- Run `05-validation/master/contract_request_reasons_validation.sql` if available
- Run `06-rollback/master/contract_request_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
