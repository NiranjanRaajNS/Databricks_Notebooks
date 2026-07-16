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

- Source: `synergy_master.document.document_ruleset` (singular)
- SAC `id` preserved; `document_id` via `migration.table_mappings` for `documents`
- `status` from `is_active` boolean
- Requires `documents` migrated first


## Special Considerations

- Requires documents table to be migrated first (for document_id mapping)
- Script performs `TRUNCATE TABLE document.document_rulesets` before insert (full table reload).
- Orchestration dependencies: `document_rules`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `document_id` | uuid | `document_id` | uuid | Map via `migration.table_mappings` where `target_table = 'documents'`; fallback first document | FK lookup |
| 3 | `name` | text | `code` | text | `COALESCE(TRIM(name), 'UNKNOWN')` | Name used as code |
| 4 | `name` | text | `name` | text | `TRIM(name)` | |
| 5 | `description` | text | `description` | text | `TRIM(description)` | |
| 6 | `effective_date` | timestamp | `effective_date` | timestamp without time zone | Direct copy | |
| 7 | `expiration_date` | timestamp | `expiration_date` | timestamp without time zone | Direct copy | |
| 8 | `is_mandatory` | boolean | `is_mandatory` | boolean | Direct copy | |
| 9 | `is_optional_if_not_present` | boolean | `is_optional_if_not_present` | boolean | Direct copy | |
| 10 | `is_bypass_approval_required` | boolean | `is_bypass_approval_required` | boolean | Direct copy | |
| 11 | `is_details_mandatory` | boolean | `is_details_mandatory` | boolean | Direct copy | |
| 12 | `is_authentication_applicable` | boolean | `is_authentication_applicable` | boolean | Direct copy | |
| 13 | `is_attachment_mandatory` | boolean | `is_attachment_mandatory` | boolean | Direct copy | |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 15 | — | — | `version` | integer | Hardcoded `1` | |
| 16 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 17 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 18 | `is_active` | boolean | `status` | integer | `is_active = true` -> Active (0); else Inactive (2) | |
| 19 | — | — | `level` | numeric | Hardcoded `0` | |
| 20 | — | — | `scope` | integer | Hardcoded `0` | Not in SAC |
| 21 | `updated_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 22 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | Direct copy | |
| 23 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.documents`
- `document_rules`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rulesets_migration.sql`

## Validation

- Run `05-validation/master/document_rulesets_validation.sql` if available
- Run `06-rollback/master/document_rulesets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
