# Table Mapping: contract_request_reasons → contract_request_reasons

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: contract_request_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: contract_request_reasons
- **Source Script**: `04-migration-scripts/master/contract_request_reasons_migration.sql`

- **Legacy Path**: `synergy_master.public.contract_request_reasons`
- **New Path**: `smac_master_migration.crewing.contract_request_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Contract Request Reasons (`contract_request_reasons` → `contract_request_reasons`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0) — Case 1
- `audit_info` validates GUID format for `*_by_id` fields; falls back to `SYSTEM_USER_ID`
- Filter: only rows where `name IS NOT NULL AND TRIM(name) <> ''`
- Second INSERT block adds seed records `'Wage Change'` and `'Date Change'` (not from SAC)

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.contract_request_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `request_type` | text | `request_type` | text | `TRIM(request_type)` | Direct copy with whitespace trimmed |
| 5 | — | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 11 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 12 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying(256) | `audit_info` | jsonb | `migration.build_audit_info()` — GUID validation on `*_by_id`; names in `notes` | Invalid GUIDs fall back to `SYSTEM_USER_ID` |
| 15 | `name` | text | `tags` | text[] | Array of generated `code` + normalized lowercase `name` tags | Special handling for `'Promotion/Change in rank'` |

**SMAC columns not migrated:** `parent_id`, `archived_at` — no source equivalent in SAC `contract_request_reasons`.

**SAC columns not migrated:** `deleted_by_id`, `deleted_by_name` — deletion tracked via `deleted_at` only.

**Additional seed records (not from SAC):** `'Wage Change'` and `'Date Change'` with `request_type = 'Amendment'`, inserted via second INSERT block.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/contract_request_reasons_migration.sql`

## Validation

- Run `05-validation/master/contract_request_reasons_validation.sql` if available
- Run `06-rollback/master/contract_request_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
