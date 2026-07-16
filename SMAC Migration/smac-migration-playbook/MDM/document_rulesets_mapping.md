# Table Mapping: document_ruleset → document_rulesets

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_ruleset
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_rulesets
- **Source Script**: `04-migration-scripts/master/document_rulesets_migration.sql`

- **Legacy Path**: `synergy_master.document.document_ruleset`
- **New Path**: `smac_master_migration.document.document_rulesets`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Ruleset (`document_ruleset` → `document_rulesets`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_ruleset preserving identifier UUID as id. document_rule_id maps to document_rules.id via migration.table_mappings. Requires document_rules table to be migrated first.

## Special Considerations

- Requires documents table to be migrated first (for document_id mapping)
- Script performs `TRUNCATE TABLE document.document_rulesets` before insert (full table reload).
- Orchestration dependencies: `document_rules`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_ruleset'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | document_id | - | COALESCE(dm.target_id, (SELECT id FROM document.documents LIMIT 1)) AS document_id | COALESCE(dm.target_id, (SELECT id FROM document.documents LIMIT 1)) |
| 3 | name | - | code | - | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') as code | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') |
| 4 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 5 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 6 | effective_date | - | effective_date | - | legacy_data.effective_date | legacy_data.effective_date |
| 7 | expiration_date | - | expiration_date | - | legacy_data.expiration_date | legacy_data.expiration_date |
| 8 | is_mandatory | - | is_mandatory | - | legacy_data.is_mandatory | legacy_data.is_mandatory |
| 9 | is_optional_if_not_present | - | is_optional_if_not_present | - | legacy_data.is_optional_if_not_present | legacy_data.is_optional_if_not_present |
| 10 | is_bypass_approval_required | - | is_bypass_approval_required | - | legacy_data.is_bypass_approval_required | legacy_data.is_bypass_approval_required |
| 11 | is_details_mandatory | - | is_details_mandatory | - | legacy_data.is_details_mandatory | legacy_data.is_details_mandatory |
| 12 | is_authentication_applicable | - | is_authentication_applicable | - | legacy_data.is_authentication_applicable | legacy_data.is_authentication_applicable |
| 13 | is_attachment_mandatory | - | is_attachment_mandatory | - | legacy_data.is_attachment_mandatory | legacy_data.is_attachment_mandatory |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | derived | - | version | - | 1 as version | 1 |
| 16 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 17 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 18 | is_active | - | status | - | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.is_active THEN 0 ELSE 2 END |
| 19 | derived | - | level | - | 0 as level | 0 |
| 20 | derived | - | scope | - | 0 as scope | 0 |
| 21 | updated_at | - | created_at | - | COALESCE(legacy_data.updated_at, NOW()) as created_at | COALESCE(legacy_data.updated_at, NOW()) |
| 22 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 23 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.documents`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rulesets_migration.sql`

## Validation

- Run `05-validation/master/document_rulesets_validation.sql` if available
- Run `06-rollback/master/document_rulesets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
