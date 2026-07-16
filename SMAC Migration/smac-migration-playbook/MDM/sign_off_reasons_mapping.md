# Table Mapping: sign_off_reasons → sign_off_reasons

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: sign_off_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: sign_off_reasons
- **Source Script**: `04-migration-scripts/master/sign_off_reasons_migration.sql`

- **Legacy Path**: `synergy_master.public.sign_off_reasons`
- **New Path**: `smac_master_migration.crewing.sign_off_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Sign Off Reasons (`sign_off_reasons` → `sign_off_reasons`)

## Migration Notes

- Preserve legacy identifier (UUID) as id (use legacy identifier directly as the new id)
- Record legacy id → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates sign_off_reasons table. Preserves legacy identifier UUID as id (source identifier is uuid, target id is uuid). Generates unique code from name + UUID suffix. Excludes deleted records (deleted_at IS NULL) and records without identifier. Legacy bigint id stored in audit_info.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.sign_off_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id, legacy_uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'sign_off_reasons'::VARCHAR(100), s.legacy_id, current_database()::text::VARCHAR(100), 'crew... |
| 2 | reason_name | - | code | - | generate_meaningful_code() | generate_meaningful_code(s.reason_name, NULL) |
| 3 | reason_name | - | name | - | COALESCE(s.reason_name, 'UNKNOWN') AS name | COALESCE(s.reason_name, 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | deleted_at | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 9 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) as created_at | COALESCE(s.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(s.updated_at, NOW()) as updated_at | COALESCE(s.updated_at, NOW()) |
| 11 | deleted_at | - | deleted_at | - | s.deleted_at as deleted_at | s.deleted_at |
| 12 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN s.created_by_id IS NOT NULL AND s.created_by_id::text <> '' THEN s.created_by_id::text ELSE NULL END::varchar, NULL::varchar, CASE WHEN s.u... |
| 13 | reason_name | - | tags | - | generate_meaningful_code() | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT generate_meaningful_code(s.reason_name, NULL) AS tag UNION ALL SELECT LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(C... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/sign_off_reasons_migration.sql`

## Validation

- Run `05-validation/master/sign_off_reasons_validation.sql` if available
- Run `06-rollback/master/sign_off_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
