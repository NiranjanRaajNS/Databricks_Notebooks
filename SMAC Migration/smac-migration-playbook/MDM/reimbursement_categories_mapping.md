# Table Mapping: reimbursement_categories → reimbursement_categories

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: reimbursement_categories
- **Source Script**: `04-migration-scripts/master/reimbursement_categories_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- reimbursement_categories are MASTER DATA
- For EACH reimbursement_type → insert ALL categories
- Categories × Types (CROSS JOIN)
- Works for ANY number of reimbursement_types
- Safe to re-run (uses resolve_target_id)
- No dependency on reimbursement_requests

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.reimbursement_categories` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'reimbursement_categories'::VARCHAR(100), (legacy.id::text || '-' || rt.id::text)::TEXT, c... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy.name, rt.name) |
| 3 | name | - | name | - | LEFT(TRIM(legacy.name), 255) AS name | LEFT(TRIM(legacy.name), 255) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | derived | - | reimbursement_type_id | - | rt.id AS reimbursement_type_id | rt.id |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | level | - | 0 AS level | 0 |
| 9 | derived | - | version | - | 1 AS version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at | - | status | - | CASE WHEN legacy.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 13 | created_at | - | created_at | - | COALESCE(legacy.created_at, NOW()) | COALESCE(legacy.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy.updated_at, NOW()) | COALESCE(legacy.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy.deleted_at | legacy.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID', NULL, :'SYSTEM_USER_ID', NULL, NULL, NULL, NULL, NULL, NULL ) |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/reimbursement_categories_migration.sql`

## Validation

- Run `05-validation/master/reimbursement_categories_validation.sql` if available
- Run `06-rollback/master/reimbursement_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
