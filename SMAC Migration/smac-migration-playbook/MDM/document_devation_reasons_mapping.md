# Table Mapping: document_bypass_reasons → document_devation_reasons

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: document_bypass_reasons
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_devation_reasons
- **Source Script**: `04-migration-scripts/master/document_devation_reasons_migration.sql`

- **Legacy Path**: `synergy_manning.public.document_bypass_reasons`
- **New Path**: `smac_master_migration.document.document_devation_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Deviation Reasons (`document_bypass_reasons` → `document_devation_reasons`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_bypass_reasons to document_devation_reasons preserving UUID as id. Generates code from name using generate_meaningful_code(). Uses standardized SMAC audit_info structure. Status defaults to Active (0) since source has no deleted_at column.

## Special Considerations

- Script performs `TRUNCATE TABLE document.document_devation_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'document_bypass_reasons'::VARCHAR(100), legacy_data.id::text, current_database()::text::VA... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 10 | - | - | updated_at | - | NULL | NULL::timestamp |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | - | - | tags | - | NULL | NULL::text[] |
| 15 | derived | - | status | - | 0 as status | 0 |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_devation_reasons_migration.sql`

## Validation

- Run `05-validation/master/document_devation_reasons_validation.sql` if available
- Run `06-rollback/master/document_devation_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
