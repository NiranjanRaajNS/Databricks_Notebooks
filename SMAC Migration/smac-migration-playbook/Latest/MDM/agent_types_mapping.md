# Table Mapping: agent_types → agent_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: agent_types
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: agent_types
- **Source Script**: `04-migration-scripts/master/agent_types_migration.sql`

- **Legacy Path**: `synergy_master.public.agent_types`
- **New Path**: `smac_master_migration.public.agent_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Agent Types (`agent_types` → `agent_types`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Pre-migration duplicate UUID check on SAC `uuid` column
- `code` generated from `name` and `identifier` via `generate_meaningful_code()`
- `status`, `level` hardcoded to 0 (Active)
- All SAC rows migrated (no filter)

## Special Considerations

- Script performs `TRUNCATE TABLE public.agent_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC uuid as SMAC id |
| 2 | `name, identifier` | text, text | `code` | text | `generate_meaningful_code(TRIM(name), TRIM(identifier))` | Generated code; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | `—` | — | `description` | text | `NULL` | No equivalent in SAC |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status column in SAC |
| 10 | `—` | — | `level` | numeric | Hardcoded `0` | No level column in SAC |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in SAC; no `legacy_id` |
| 14 | `name, identifier` | text, text | `tags` | text[] | Distinct array from generated code + normalized name (lowercase, special chars → underscores) | Derived search tags |

**SAC columns not migrated:** Legacy bigint `id` used only as `source_id` in mappings.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/agent_types_migration.sql`

## Validation

- Run `05-validation/master/agent_types_validation.sql` if available
- Run `06-rollback/master/agent_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
