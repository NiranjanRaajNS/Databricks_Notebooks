# Table Mapping: rank_type → rank_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: rank_type
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: rank_types
- **Source Script**: `04-migration-scripts/master/rank_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.rank_type`
- **New Path**: `smac_master_migration.public.rank_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Rank Type (`rank_type` → `rank_types`)

## Migration Notes

- Source: `synergy_master.enum.rank_type` → `public.rank_types`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier` (source_id = integer `id`)
- Pre-migration duplicate UUID check on `identifier`
- Staging table dedup by identifier; includes SAC `tags` column
- `code` extensive CASE mapping (SUPPORT→SUP, OPERATIONS→OPS, etc.)
- `tags` derived from code + normalized name slug in SMAC
- Mappings auto-stored by `resolve_target_id()`

## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | smallint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` |  |
| 2 | `name` | text | `code` | text | CASE: SUPPORT→`SUP`, OPERATIONS→`OPS`, OFFICER→`OFF`, etc.; else first 3 chars |  |
| 3 | `name` | text | `name` | text | `COALESCE(rank_type_name, 'UNKNOWN')` |  |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 8 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 11 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 13 | `name` | text | `tags` | text[] | Array from lowercase code tag + normalized name slug (deduplicated) | SAC `tags` not copied directly |

**SAC columns not migrated:** `tags` (SAC column exists but SMAC tags are regenerated from code/name).

**SMAC columns not migrated:** `deleted_at`, `description`.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/rank_types_migration.sql`

## Validation

- Run `05-validation/master/rank_types_validation.sql` if available
- Run `06-rollback/master/rank_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
