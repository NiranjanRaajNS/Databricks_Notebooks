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

- Source: `synergy_master.document.document_rule` (singular)
- SAC `id` preserved; `document_ruleset_id` and `document_rule_type_id` use preserved UUIDs directly
- `rule_value` transformed: LessThanOrEqual -> string array; else `migration.resolve_rule_value_id()`
- Post-migration UPDATE: vessel rule values remapped to `vessel_revisions` IDs


## Special Considerations

- Requires document_rule_types and document_rulesets to be migrated first
- Script performs `TRUNCATE TABLE document.document_rules` before insert (full table reload).
- Orchestration dependencies: `document_rule_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `ruleset_id` | uuid | `document_ruleset_id` | uuid | Direct copy (UUID preserved) | Same UUID in source/target |
| 3 | `rule_type_id` | uuid | `document_rule_type_id` | uuid | Direct copy (UUID preserved) | Same UUID in source/target |
| 4 | `rule_operator` | text | `rule_operator` | text | `TRIM(rule_operator)` | |
| 5 | `rule_value` | text[] | `rule_value` | jsonb | LessThanOrEqual -> string JSONB array; else `resolve_rule_value_id()` per element | Empty array when NULL |
| 6 | `priority` | integer | `priority` | integer | Direct copy | |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 8 | — | — | `version` | integer | Hardcoded `1` | |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 11 | `is_active` | boolean | `status` | integer | `is_active = true` -> Active (0); else Inactive (2) | |
| 12 | — | — | `level` | numeric | Hardcoded `0` | |
| 13 | `updated_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | Direct copy | |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |

**Post-migration changes:** UPDATE vessel-type `rule_value` entries to use `vessel_revisions.id` instead of `vessels.id`.


## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.document_rule_types`
- `document.document_rulesets`
- `document_rule_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rules_migration.sql`

## Validation

- Run `05-validation/master/document_rules_validation.sql` if available
- Run `06-rollback/master/document_rules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
