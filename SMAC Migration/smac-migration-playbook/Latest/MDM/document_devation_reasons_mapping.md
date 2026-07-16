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

- Source: `synergy_manning.public.document_bypass_reasons` -> `document.document_devation_reasons`
- SAC `uuid` preserved via `migration.resolve_target_id()` with `p_target_id = uuid`
- Pre-migration duplicate UUID check on SAC `uuid`
- Same source rows as `document_bypass_reasons` migration (all bypass reasons copied)


## Special Considerations

- Script performs `TRUNCATE TABLE document.document_devation_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | UUID preserved; target table differs |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | Not in SAC |
| 5 | — | — | `level` | numeric | Hardcoded `0` | |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 7 | — | — | `parent_id` | uuid | `NULL` | Not in SAC |
| 8 | — | — | `version` | integer | Hardcoded `1` | |
| 9 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not in SAC |
| 10 | — | — | `updated_at` | timestamp without time zone | `NULL` | Not in SAC |
| 11 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |
| 14 | — | — | `tags` | text[] | `NULL` | Not populated |
| 15 | — | — | `status` | integer | Hardcoded `0` (Active) | |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_devation_reasons_migration.sql`

## Validation

- Run `05-validation/master/document_devation_reasons_validation.sql` if available
- Run `06-rollback/master/document_devation_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
