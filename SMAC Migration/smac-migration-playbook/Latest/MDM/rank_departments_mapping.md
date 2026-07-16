# Table Mapping: rank_departments → rank_departments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: rank_departments
- **Source Script**: `04-migration-scripts/master/rank_departments_migration.sql`


## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- Source: distinct `department` from `synergy_master.public.ranks` → `public.rank_departments`
- `resolve_target_id()` with source_id = department name text; `p_target_id = NULL`
- `DISTINCT ON (LOWER(TRIM(department)))` deduplication
- TRUNCATE target
- `code` CASE mapping: ENGINE→ENG, DECK→DEC, etc.; fallback first 3 chars
- Filter: `department IS NOT NULL AND TRIM <> ''`
- `status`/`level` hardcoded `0`; timestamps `NOW()`
## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_departments` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `department` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = `department_name::text`; `p_target_id = NULL` | Text-based key |
| 2 | `department` | text | `code` | text | CASE: ENGINE→`ENG`, DECK→`DEC`, CATERING→`CAT`, etc.; else first 3 chars |  |
| 3 | `department` | text | `name` | text | `TRIM(department_name)` |  |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 8 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 11 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** All other `ranks` columns.

**SMAC columns not migrated:** `deleted_at`, `description`, `tags`.",
)

# --- rank_types ---
set_update(
    "rank_types",
    [
        "- Source: `synergy_master.enum.rank_type` → `public.rank_types`",
        "- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier` (source_id = integer `id`)",
        "- Pre-migration duplicate UUID check on `identifier`",
        "- Staging table dedup by identifier; includes SAC `tags` column",
        "- `code` extensive CASE mapping (SUPPORT→SUP, OPERATIONS→OPS, etc.)",
        "- `tags` derived from code + normalized name slug in SMAC",
        "- Mappings auto-stored by `resolve_target_id()`",
    ],
    [
        row(1, "id, identifier", "smallint, uuid", "id", "uuid", "`migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier`", "
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/rank_departments_migration.sql`

## Validation

- Run `05-validation/master/rank_departments_validation.sql` if available
- Run `06-rollback/master/rank_departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
