# Table Mapping: drug_alcohol_test_types → drug_alcohol_test_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: drug_alcohol_test_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: drug_alcohol_test_types
- **Source Script**: `04-migration-scripts/master/drug_alcohol_test_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.drug_alcohol_test_types`
- **New Path**: `smac_master_migration.crewing.drug_alcohol_test_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Drug Alcohol Test Types (`drug_alcohol_test_types` → `drug_alcohol_test_types`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `code` from uppercase `name` with spaces -> underscores
- `status` hardcoded Active (0)
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`


## Special Considerations

- Script performs `TRUNCATE TABLE crewing.drug_alcohol_test_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `name` | text | `code` | text | `UPPER(REPLACE(TRIM(name), ' ', '_'))` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | Not in SAC |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 6 | — | — | `version` | integer | Hardcoded `1` | |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 9 | — | — | `status` | integer | Hardcoded `0` (Active) | |
| 10 | — | — | `level` | numeric | Hardcoded `0` | |
| 11 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 12 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/drug_alcohol_test_types_migration.sql`

## Validation

- Run `05-validation/master/drug_alcohol_test_types_validation.sql` if available
- Run `06-rollback/master/drug_alcohol_test_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
