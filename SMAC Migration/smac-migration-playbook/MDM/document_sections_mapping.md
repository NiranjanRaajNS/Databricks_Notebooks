# Table Mapping: document_sections → document_sections

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_sections
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_sections
- **Source Script**: `04-migration-scripts/master/document_sections_migration.sql`

- **Legacy Path**: `synergy_master.document.document_sections`
- **New Path**: `smac_master_migration.document.document_sections`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Sections (`document_sections` → `document_sections`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- document_type_id column not included - target table doesn't have this column
- document_type_id column removed - target table doesn't have this column
- document_type_id mapping removed - target table doesn't have this column
- Migrates document_sections preserving identifier UUID as id. document_type_id maps to document_types.id via migration.table_mappings. Requires document_types table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE document.document_sections` before insert (full table reload).
- Orchestration dependencies: `document_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_sections'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | code, name | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), LEFT(TRIM(legacy_data.name), 10)) as code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), LEFT(TRIM(legacy_data.name), 10)) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | status | - | status | - | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... |
| 9 | derived | - | level | - | 0 as level | 0 |
| 10 | audit_info | - | created_at | - | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'CreatedAt' AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL AND legacy_data.audit_info->>'CreatedA... | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'CreatedAt' AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL AND legacy_data.audit_info->>'CreatedA... |
| 11 | audit_info | - | updated_at | - | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'UpdatedAt' AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL AND legacy_data.audit_info->>'UpdatedA... | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'UpdatedAt' AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL AND legacy_data.audit_info->>'UpdatedA... |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_sections_migration.sql`

## Validation

- Run `05-validation/master/document_sections_validation.sql` if available
- Run `06-rollback/master/document_sections_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
