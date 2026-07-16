# Table Mapping: reliefType → relief_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: reliefType
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: relief_types
- **Source Script**: `04-migration-scripts/master/relief_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.reliefType`
- **New Path**: `smac_master_migration.crewing.relief_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Relief Types (`reliefType` → `relief_types`)

## Migration Notes

- Source: `synergy_master.enum.relieftype` → `crewing.relief_types`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- TRUNCATE target
- Filter: non-empty `name`
- Second INSERT: synthetic `'Rotation'` seed row if not exists
- `tags` derived from code + normalized name
- `status` hardcoded Active (0); timestamps `NOW()`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.relief_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` |  |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` |  |
| 3 | `name` | text | `name` | text | `TRIM(name)` |  |
| 4 | `name` | text | `description` | text | `TRIM(name)` | Same as name |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 10 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 11 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 12 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 13 | `—` | — | `deleted_at` | timestamp | `NULL` |  |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 15 | `name` | text | `tags` | text[] | Array from code tag + lowercase normalized name slug |  |

**SAC columns not migrated:** None from dblink SELECT.

**Additional seed record:** `'Rotation'` inserted via second INSERT if code not exists.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/relief_types_migration.sql`

## Validation

- Run `05-validation/master/relief_types_validation.sql` if available
- Run `06-rollback/master/relief_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
