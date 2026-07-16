# Table Mapping: document_field_definition → document_field_definitions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_field_definition
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_field_definitions
- **Source Script**: `04-migration-scripts/master/document_field_definitions_migration.sql`

- **Legacy Path**: `synergy_master.document.document_field_definition`
- **New Path**: `smac_master_migration.document.document_field_definitions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Field Definition (`document_field_definition` → `document_field_definitions`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_field_definition preserving identifier UUID as id. document_part_id maps to documents.id via migration.table_mappings. Requires documents table to be migrated first.

## Special Considerations

- Requires documents table to be migrated first (for document_id and document_part_id mapping)
- Script performs `TRUNCATE TABLE document.document_field_definitions` before insert (full table reload).
- Orchestration dependencies: `documents`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_field_definition'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | document_id | - | dm_doc.target_id AS document_id | dm_doc.target_id |
| 3 | derived | - | document_part_id | - | COALESCE(dm_part.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS document_part_id | COALESCE(dm_part.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | name, id | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.id::text) |
| 5 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 6 | label | - | label | - | TRIM(legacy_data.label) as label | TRIM(legacy_data.label) |
| 7 | type | - | type | - | TRIM(legacy_data.type) as type | TRIM(legacy_data.type) |
| 8 | is_required | - | is_required | - | COALESCE(legacy_data.is_required, FALSE) as is_required | COALESCE(legacy_data.is_required, FALSE) |
| 9 | is_readonly | - | is_readonly | - | COALESCE(legacy_data.is_readonly, FALSE) as is_readonly | COALESCE(legacy_data.is_readonly, FALSE) |
| 10 | name, meta_data | - | meta_data | - | CASE WHEN LOWER(TRIM(legacy_data.name)) = 'country' AND legacy_data.meta_data IS NOT NULL AND legacy_data.meta_data ? 'DataSourceInfo' THEN jsonb_build_object( 'DataSourceInfo',... | CASE WHEN LOWER(TRIM(legacy_data.name)) = 'country' AND legacy_data.meta_data IS NOT NULL AND legacy_data.meta_data ? 'DataSourceInfo' THEN jsonb_build_object( 'DataSourceInfo',... |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | derived | - | version | - | 1 as version | 1 |
| 13 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 14 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 15 | is_active | - | status | - | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END |
| 16 | derived | - | level | - | COALESCE(legacy_data."order", 0) as level | COALESCE(legacy_data."order", 0) |
| 17 | updated_at | - | created_at | - | COALESCE(legacy_data.updated_at, NOW()) as created_at | COALESCE(legacy_data.updated_at, NOW()) |
| 18 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 19 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 20 | name, id | - | tags | - | generate_meaningful_code() | CASE WHEN LOWER(generate_meaningful_code(TRIM(legacy_data.name), legacy_data.id::text)) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.documents`
- `public.countries`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_field_definitions_migration.sql`

## Validation

- Run `05-validation/master/document_field_definitions_validation.sql` if available
- Run `06-rollback/master/document_field_definitions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
