# Table Mapping: document_rule → document_rules

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_rule
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_rules
- **Source Script**: `04-migration-scripts/master/document_rules_migration.sql`

- **Legacy Path**: `synergy_master.document.document_rule`
- **New Path**: `smac_master_migration.document.document_rules`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Rule (`document_rule` → `document_rules`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_rule preserving identifier UUID as id. document_rule_type_id maps to document_rule_types.id via migration.table_mappings. Requires document_rule_types table to be migrated first.

## Special Considerations

- Requires document_rule_types and document_rulesets to be migrated first
- Script performs `TRUNCATE TABLE document.document_rules` before insert (full table reload).
- Orchestration dependencies: `document_rule_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_rule'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100... |
| 2 | ruleset_id | - | document_ruleset_id | - | legacy_data.ruleset_id AS document_ruleset_id | legacy_data.ruleset_id |
| 3 | rule_type_id | - | document_rule_type_id | - | legacy_data.rule_type_id AS document_rule_type_id | legacy_data.rule_type_id |
| 4 | rule_operator | - | rule_operator | - | TRIM(legacy_data.rule_operator) as rule_operator | TRIM(legacy_data.rule_operator) |
| 5 | rule_value, rule_operator, rule_type_id | - | rule_value | - | CASE WHEN legacy_data.rule_value IS NULL OR array_length(legacy_data.rule_value, 1) IS NULL THEN '[]'::jsonb WHEN UPPER(TRIM(legacy_data.rule_operator)) = 'LESSTHANOREQUAL' THEN... | CASE WHEN legacy_data.rule_value IS NULL OR array_length(legacy_data.rule_value, 1) IS NULL THEN '[]'::jsonb WHEN UPPER(TRIM(legacy_data.rule_operator)) = 'LESSTHANOREQUAL' THEN... |
| 6 | priority | - | priority | - | COALESCE(legacy_data.priority, 0) as priority | COALESCE(legacy_data.priority, 0) |
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

- `document.document_rule_types`
- `document.document_rulesets`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rules_migration.sql`

## Validation

- Run `05-validation/master/document_rules_validation.sql` if available
- Run `06-rollback/master/document_rules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
