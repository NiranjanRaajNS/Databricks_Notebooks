# Table Mapping: document_rule_type → document_rule_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_rule_type
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_rule_types
- **Source Script**: `04-migration-scripts/master/document_rule_types_migration.sql`

- **Legacy Path**: `synergy_master.document.document_rule_type`
- **New Path**: `smac_master_migration.document.document_rule_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Rule Type (`document_rule_type` → `document_rule_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_rule_type preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE document.document_rule_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_rule_type'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | rule_type_code | - | code | - | COALESCE(TRIM(legacy_data.rule_type_code), 'UNKNOWN') as code | COALESCE(TRIM(legacy_data.rule_type_code), 'UNKNOWN') |
| 3 | rule_type | - | name | - | TRIM(legacy_data.rule_type) as name | TRIM(legacy_data.rule_type) |
| 4 | rule_type | - | rule_type | - | ARRAY[TRIM(legacy_data.rule_type)]::varchar(100)[] as rule_type | ARRAY[TRIM(legacy_data.rule_type)]::varchar(100)[] |
| 5 | field_type | - | field_type | - | TRIM(legacy_data.field_type) as field_type | TRIM(legacy_data.field_type) |
| 6 | data_source | - | data_source | - | legacy_data.data_source as data_source | legacy_data.data_source |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | is_active | - | status | - | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END |
| 12 | derived | - | level | - | 0 as level | 0 |
| 13 | updated_at | - | created_at | - | COALESCE(legacy_data.updated_at, NOW()) as created_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rule_types_migration.sql`

## Validation

- Run `05-validation/master/document_rule_types_validation.sql` if available
- Run `06-rollback/master/document_rule_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
