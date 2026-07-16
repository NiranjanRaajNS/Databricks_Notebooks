# Table Mapping: cbas → cbas

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cbas
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cbas
- **Source Script**: `04-migration-scripts/master/cbas_migration.sql`

- **Legacy Path**: `synergy_master.public.cbas`
- **New Path**: `smac_master_migration.crewing.cbas`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cbas (`cbas` → `cbas`)

## Migration Notes

- Source `id` is bigint — `migration.resolve_target_id()` with `p_target_id = NULL`
- `cba_type_id` via direct join to `crewing.cba_types` on legacy `cba_type` uuid
- `currency_id` via `currencies.code` match
- `is_all_nationalities` when nationality JSONB contains `'ALL'`
- `status` from `deleted_at` (Case 1)
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.cbas` before insert (full table reload).
- Orchestration dependencies: `cba_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `code` | text | `code` | text | `UPPER(TRIM(code))` | Direct copy uppercased |
| 3 | `name` | text | `name` | text | `UPPER(TRIM(name))` | Direct copy uppercased |
| 4 | `cba_type` | uuid | `cba_type_id` | uuid | Direct join `cba_types.id = cba_type` | FK: `cba_types` |
| 5 | `currency` | text | `currency_id` | uuid | Join `currencies` on `UPPER(TRIM(code))` | FK: `currencies` |
| 6 | `description` | text | `description` | text | `TRIM(description)` or NULL when empty |  |
| 7 | `include_superior_certificate` | boolean | `include_superior_certificate` | boolean | `COALESCE(include_superior_certificate, false)` |  |
| 8 | `nationality` | jsonb | `is_all_nationalities` | boolean | `true` when JSONB contains `'ALL'` |  |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 15 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 16 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 17 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 18 | `created_by_id, updated_by_id` | character varying | `audit_info` | jsonb | `jsonb_build_object()` Pattern 1 | `legacy_id` in audit_info |

**SAC columns not migrated:** `alpha2_code`, `created_by_name`, `updated_by_name`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cba_types`
- `crewing.cba_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/cbas_migration.sql`

## Validation

- Run `05-validation/master/cbas_validation.sql` if available
- Run `06-rollback/master/cbas_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
