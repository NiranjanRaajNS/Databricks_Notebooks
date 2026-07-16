# Table Mapping: account_type → bank_account_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: account_type
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: bank_account_types
- **Source Script**: `04-migration-scripts/master/bank_account_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.account_type`
- **New Path**: `smac_master_migration.public.bank_account_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Account Type (`account_type` → `bank_account_types`)

## Migration Notes

- SAC `identifier` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- `code` generated as `UPPER(TRIM(name))` — SAC `code` column not used
- Filter: `identifier IS NOT NULL AND TRIM(name) <> ''`

## Special Considerations

- Script performs `TRUNCATE TABLE public.bank_account_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves identifier uuid as SMAC id |
| 2 | `name` | text | `code` | text | `UPPER(TRIM(name))` | Generated from name; SAC `code` not used |
| 3 | `name` | text | `name` | text | `COALESCE(NULLIF(TRIM(name), ''), 'UNKNOWN')` | NOT NULL in SMAC |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 5 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 8 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status column in SAC |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` | No level column in SAC |
| 10 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No timestamps in SAC enum table |
| 11 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | No timestamps in SAC enum table |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in SAC |

**SAC columns not migrated:** `code` — name used for SMAC `code` instead.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/bank_account_types_migration.sql`

## Validation

- Run `05-validation/master/bank_account_types_validation.sql` if available
- Run `06-rollback/master/bank_account_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
