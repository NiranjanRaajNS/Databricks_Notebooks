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

- Source: `synergy_master.document.document_rule_type` (singular table name)
- SAC `id` preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `code` from `rule_type_code`; `name` from `rule_type`
- `status` from `is_active` boolean (true->Active, false->Inactive)


## Special Considerations

- Script performs `TRUNCATE TABLE document.document_rule_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `rule_type_code` | text | `code` | text | `COALESCE(TRIM(rule_type_code), 'UNKNOWN')` | |
| 3 | `rule_type` | text | `name` | text | `TRIM(rule_type)` | |
| 4 | `rule_type` | text | `rule_type` | character varying(100)[] | `ARRAY[TRIM(rule_type)]` | Single-element array |
| 5 | `field_type` | text | `field_type` | text | `TRIM(field_type)` | |
| 6 | `data_source` | jsonb | `data_source` | jsonb | Direct copy | |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 8 | — | — | `version` | integer | Hardcoded `1` | |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 11 | `is_active` | boolean | `status` | integer | `is_active = true` -> Active (0); else Inactive (2) | |
| 12 | — | — | `level` | numeric | Hardcoded `0` | |
| 13 | `updated_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | SAC `updated_at` used as created_at |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | Direct copy | |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_rule_types_migration.sql`

## Validation

- Run `05-validation/master/document_rule_types_validation.sql` if available
- Run `06-rollback/master/document_rule_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
