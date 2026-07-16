# Table Mapping: dgstatus → dg_statuses

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: dgstatus
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: dg_statuses
- **Source Script**: `04-migration-scripts/master/dg_statuses_migration.sql`

- **Legacy Path**: `synergy_master.enum.dgstatus`
- **New Path**: `smac_master_migration.crewing.dg_statuses`

## Business Key

- **Business Key**: `d.identifier`

## Migration Notes

- Preserve legacy identifier (UUID) as id (use legacy identifier directly as the new id)
- Record legacy id (integer) → new uuid (identifier) in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Only name column exists (label and value columns don't exist in this table)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.dg_statuses` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_uuid | - | id | - | s.legacy_uuid AS id | s.legacy_uuid |
| 2 | status_name | - | code | - | LEFT(UPPER(REPLACE(LEFT(TRIM(s.status_name), 15), ' ', '_')), 50) AS code | LEFT(UPPER(REPLACE(LEFT(TRIM(s.status_name), 15), ' ', '_')), 50) |
| 3 | status_name | - | name | - | LEFT(COALESCE(s.status_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.status_name, 'UNKNOWN'), 255) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 7 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 11 | legacy_id | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |
| 12 | status_name | - | tags | - | CASE WHEN LOWER(LEFT(UPPER(REPLACE(LEFT(TRIM(s.status_name), 15), ' ', '_')), 50)) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(COALESCE(s.status_name, 'UNKNOWN'), 255), ' ', '... | CASE WHEN LOWER(LEFT(UPPER(REPLACE(LEFT(TRIM(s.status_name), 15), ' ', '_')), 50)) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(COALESCE(s.status_name, 'UNKNOWN'), 255), ' ', '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/dg_statuses_migration.sql`

## Validation

- Run `05-validation/master/dg_statuses_validation.sql` if available
- Run `06-rollback/master/dg_statuses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
