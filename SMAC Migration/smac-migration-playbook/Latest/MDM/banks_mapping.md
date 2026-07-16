# Table Mapping: banks → banks

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: banks
- **Source Script**: `04-migration-scripts/master/banks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.bank_details.bank_name (distinct values)`
- **New Path**: `smac_master_migration.public.banks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Bank Details (`bank_details` → `banks`)

## Migration Notes

- Distinct bank names from `bank_details`; SAC `uuid` preserved as SMAC `id` when available
- `code` from `ifsc_code` or generated from `bank_name` via regex replace
- Filter: `bank_name IS NOT NULL`, `TRIM(bank_name) <> ''`, `deleted_at IS NULL` (deleted SAC rows excluded)
- `defined_by`, `workflow_status`, `status` hardcoded to `0` (not constants.sql vars)

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE public.banks` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid` | uuid | `id` | uuid | `COALESCE(uuid, gen_random_uuid())` | Preserves SAC uuid when available |
| 2 | `ifsc_code, bank_name` | text, text | `code` | text | `COALESCE(NULLIF(TRIM(ifsc_code), ''), UPPER(REGEXP_REPLACE(TRIM(bank_name), ...)))` | IFSC preferred; fallback from bank name |
| 3 | `bank_name` | text | `name` | text | `TRIM(bank_name)` | NOT NULL in SMAC |
| 4 | `—` | — | `description` | text | `NULL` | No description in SAC |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` | No level in SAC |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `parent_id` | uuid | `NULL` | No parent in SAC |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not from constants.sql in script |
| 10 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not from constants.sql in script |
| 11 | `—` | — | `status` | integer | Hardcoded `0` (Active) | Source filtered to non-deleted rows |
| 12 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No timestamps migrated from SAC |
| 13 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | No timestamps migrated from SAC |
| 14 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Deleted SAC rows excluded by filter |
| 15 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | No source equivalent |
| 16 | `—` | — | `tags` | text[] | Empty array `ARRAY[]::text[]` | Not populated |
| 17 | `uuid, bank_name, ifsc_code` | uuid, text, text | `audit_info` | jsonb | `jsonb_build_object()` with `legacy_id`, `legacy_uuid`, `legacy_bank_name`, `legacy_ifsc_code` | Pattern 2 + legacy metadata |

**SAC columns not migrated:** `branch_name`, `address`, `contact`, `state_id`, `country_id` — used only in `bank_branches` migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/banks_migration.sql`

## Validation

- Run `05-validation/master/banks_validation.sql` if available
- Run `06-rollback/master/banks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
