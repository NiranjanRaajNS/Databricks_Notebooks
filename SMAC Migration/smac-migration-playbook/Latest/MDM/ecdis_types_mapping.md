# Table Mapping: ecdis_types → ecdis_types

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ecdis_types
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: ecdis_types
- **Source Script**: `04-migration-scripts/master/ecdis_types_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ecdis_types`
- **New Path**: `smac_master_migration.vessel.ecdis_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ecdis Types (`ecdis_types` → `ecdis_types`)

## Migration Notes

- Source: `synergy_vessel.public.ecdis_types`
- SAC `identifier` preserved via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier`
- `code` from `generate_meaningful_code(name, identifier)`
- `status` Case 2 from `deleted_at` + `status` text


## Special Considerations

- Script performs `TRUNCATE TABLE vessel.ecdis_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | UUID preserved |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | Not in SAC |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 6 | — | — | `version` | integer | Hardcoded `1` | |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 9 | `deleted_at`, `status` | timestamp, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | |
| 10 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 11 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 12 | — | — | `level` | numeric | Hardcoded `0` | |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No `legacy_id` |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/ecdis_types_migration.sql`

## Validation

- Run `05-validation/master/ecdis_types_validation.sql` if available
- Run `06-rollback/master/ecdis_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
