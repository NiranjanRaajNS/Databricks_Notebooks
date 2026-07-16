# Table Mapping: departure_checklists → departure_checklist

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: departure_checklists
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: departure_checklist
- **Source Script**: `04-migration-scripts/master/departure_checklist_migration.sql`

- **Legacy Path**: `synergy_manning.public.departure_checklists`
- **New Path**: `smac_master_migration.crewing.departure_checklist`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Departure Checklist (`departure_checklists` → `departure_checklist`)

## Migration Notes

- Source: `synergy_manning.public.departure_checklists` filtered by tag `departure_checklist`
- Source `id` (bigint) -> `migration.resolve_target_id()` with `p_target_id = NULL`
- `code` generated from `name` via `generate_meaningful_code()`
- `status` derived from `deleted_at` — Case 1
- Filter: `name IS NOT NULL AND TRIM(name) <> ''` plus tag join


## Special Considerations

- Run 01-discovery/master/inspect_departure_checklists_schema.sql FIRST to verify schema
- Script performs `TRUNCATE TABLE crewing.departure_checklist` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `name` | character varying | `code` | text | `generate_meaningful_code(name, NULL)` | SAC has no code column |
| 3 | `name` | character varying | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 5 | — | — | `parent_id` | uuid | `NULL` | Not in SAC |
| 6 | — | — | `level` | numeric | Hardcoded `0` | |
| 7 | — | — | `version` | integer | Hardcoded `1` | |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 10 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` -> Deleted (3); else Active (0) | Case 1 |
| 11 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 12 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 13 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | All records migrated |
| 14 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |
| 16 | — | — | `tags` | text[] | `NULL` | Not populated |

**SAC filter:** JOIN `taggings`/`tags` where `tags.name = 'departure_checklist'`.


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/departure_checklist_migration.sql`

## Validation

- Run `05-validation/master/departure_checklist_validation.sql` if available
- Run `06-rollback/master/departure_checklist_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
