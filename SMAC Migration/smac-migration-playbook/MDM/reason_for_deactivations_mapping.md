# Table Mapping: reason_for_deactivations → reason_for_deactivations

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: reason_for_deactivations
- **Source Script**: `04-migration-scripts/master/reason_for_deactivations_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Reason for Deactivations (`seafarer_profile_remarks` → `reason_for_deactivations`)

## Migration Notes

- Extract distinct values from name and description columns in seafarer_profile_remarks table
- Generate new UUIDs for each distinct name/description combination
- Map name and description directly to target table
- Record legacy value → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates distinct values from seafarer_profile_remarks.deactivation_reason column

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.reason_for_deactivations` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | deactivation_reason_name | - | id | - | migration.resolve_target_id() | DISTINCT ON (LOWER(TRIM(s.deactivation_reason_name))) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_profile_remarks'::VARCHAR(... |
| 2 | deactivation_reason_name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(s.deactivation_reason_name), NULL) |
| 3 | deactivation_reason_name | - | name | - | LEFT(COALESCE(s.deactivation_reason_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.deactivation_reason_name, 'UNKNOWN'), 255) |
| 4 | deactivation_reason_description | - | description | - | LEFT(COALESCE(s.deactivation_reason_description, ''), 1000) AS description | LEFT(COALESCE(s.deactivation_reason_description, ''), 1000) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 11 | updated_at, created_at | - | updated_at | - | COALESCE(s.updated_at, s.created_at, NOW()) AS updated_at | COALESCE(s.updated_at, s.created_at, NOW()) |
| 12 | deactivation_reason_description, deactivation_reason_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/reason_for_deactivations_migration.sql`

## Validation

- Run `05-validation/master/reason_for_deactivations_validation.sql` if available
- Run `06-rollback/master/reason_for_deactivations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
