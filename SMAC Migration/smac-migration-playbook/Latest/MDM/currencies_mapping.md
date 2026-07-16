# Table Mapping: currencies → currencies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: currencies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: currencies
- **Source Script**: `04-migration-scripts/master/currencies_migration.sql`

- **Legacy Path**: `synergy_master.public.currencies`
- **New Path**: `smac_master_migration.public.currencies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Currencies (`currencies` → `currencies`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL`
- `name` from static `currency_name_mappings` temp table (~160 ISO codes) or falls back to uppercase `code`
- `symbol` set to NULL initially; post-migration UPDATE populates symbols
- `is_contract_currency` mapped from SAC `is_cba_currency`
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0) — Case 1
- Post-migration: symbol UPDATE, name UPDATE, INSERT missing ISO currency codes
- SAC has no uuid/identifier column — duplicate UUID check skipped

## Special Considerations

- Script performs `TRUNCATE TABLE public.currencies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `code` | text | `code` | text | `TRIM(code)` | Direct copy; NOT NULL in SMAC |
| 3 | `code` | text | `name` | text | `COALESCE(currency_name_mappings.name, UPPER(TRIM(code)))` | Static ISO name lookup table; fallback to code |
| 4 | — | — | `symbol` | text | `NULL` (post-migration UPDATE) | Populated after initial INSERT |
| 5 | `is_cba_currency` | boolean | `is_contract_currency` | boolean | `COALESCE(is_cba_currency, false)` | Direct boolean mapping |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 11 | — | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 12 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 13 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; legacy `is_cba_currency` in `notes` | Standardized SMAC audit structure |
| 16 | `code` | text | `tags` | text[] | Distinct array of `code` + lowercase `name` tags | Derived search tags |

**SMAC columns not migrated:** `currency_rate_available` — set later by `currency_exchange_rate` migration.

**SAC columns not migrated:** None from dblink SELECT.

**Post-migration changes (not from SAC column mapping):**
- UPDATE `symbol` from static mapping
- UPDATE `name` from static mapping
- INSERT missing ISO currency codes not in SAC

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/currencies_migration.sql`

## Validation

- Run `05-validation/master/currencies_validation.sql` if available
- Run `06-rollback/master/currencies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
