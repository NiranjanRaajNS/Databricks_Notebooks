# Table Mapping: vesselonboardingstate → profile_states

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: vesselonboardingstate
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: profile_states
- **Source Script**: `04-migration-scripts/master/profile_states_migration.sql`

- **Legacy Path**: `synergy_master.enum.vesselonboardingstate`
- **New Path**: `smac_master_migration.crewing.profile_states`

## Business Key

- **Business Key**: `d.identifier`

## Migration Notes

- Preserve legacy identifier (UUID) as id (use legacy identifier directly as the new id)
- Record legacy id (integer) → new uuid (identifier) in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Use legacy id as level (enum tables typically use id for ordering)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.profile_states` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_uuid | - | id | - | s.legacy_uuid AS id | s.legacy_uuid |
| 2 | state_name | - | code | - | LEFT(UPPER(REPLACE(LEFT(TRIM(s.state_name), 15), ' ', '_')), 50) AS code | LEFT(UPPER(REPLACE(LEFT(TRIM(s.state_name), 15), ' ', '_')), 50) |
| 3 | state_name | - | name | - | LEFT(COALESCE(s.state_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.state_name, 'UNKNOWN'), 255) |
| 4 | legacy_level | - | level | - | s.legacy_level AS level | s.legacy_level |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/profile_states_migration.sql`

## Validation

- Run `05-validation/master/profile_states_validation.sql` if available
- Run `06-rollback/master/profile_states_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
