# Table Mapping: officertype → officer_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: officertype
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: officer_types
- **Source Script**: `04-migration-scripts/master/officer_types_migration.sql`

- **Legacy Path**: `synergy_master.enum.officertype`
- **New Path**: `smac_master_migration.public.officer_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Officertype (`officertype` → `officer_types`)

## Migration Notes

- Source: `synergy_master.enum.officertype` → `public.officer_types`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- TRUNCATE target
- `level` = `ROW_NUMBER() OVER (ORDER BY name) - 1` (alphabetical)
- `tags` derived from generated code + normalized name
- Timestamps set to `NOW()`; `status` hardcoded Active (0)

## Special Considerations

- Script performs `TRUNCATE TABLE public.officer_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | integer, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` |  |
| 2 | `name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` |  |
| 3 | `name` | text | `name` | text | `TRIM(name)` |  |
| 4 | `—` | — | `description` | text | `NULL` | No SAC column |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 6 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 10 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 11 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name)) - 1` | Alphabetical order |
| 12 | `—` | — | `created_at` | timestamptz | `NOW()` |  |
| 13 | `—` | — | `updated_at` | timestamptz | `NOW()` |  |
| 14 | `—` | — | `deleted_at` | timestamptz | `NULL` |  |
| 15 | `—` | — | `archived_at` | timestamptz | `NULL` |  |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 17 | `name` | text | `tags` | text[] | Distinct array from generated code + lowercase normalized name slug | Derived |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/officer_types_migration.sql`

## Validation

- Run `05-validation/master/officer_types_validation.sql` if available
- Run `06-rollback/master/officer_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
