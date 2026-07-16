# Table Mapping: reimbursement_types → reimbursement_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: reimbursement_types
- **Source Script**: `04-migration-scripts/master/reimbursement_types_migration.sql`


## Migration Notes

- Extract distinct values from request_type column in reimbursement_requests table
- Generate new UUIDs for each distinct request_type value
- Record legacy value → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.reimbursement_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | request_type, request_type_name | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'reimbursement_requests.request_type'::VARCHAR(100), LEFT(s.request_type_name, 100)::text,... |
| 2 | request_type_name | - | code | - | generate_meaningful_code() | generate_meaningful_code(s.request_type_name, NULL) |
| 3 | request_type_name | - | name | - | LEFT(COALESCE(s.request_type_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.request_type_name, 'UNKNOWN'), 255) |
| 4 | derived | - | level | - | 0 as level | 0 |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 11 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(s.updated_at, s.created_at, NOW()) AS updated_at | COALESCE(s.updated_at, s.created_at, NOW()) |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/reimbursement_types_migration.sql`

## Validation

- Run `05-validation/master/reimbursement_types_validation.sql` if available
- Run `06-rollback/master/reimbursement_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
