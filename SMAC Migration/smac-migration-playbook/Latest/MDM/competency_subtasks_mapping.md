# Table Mapping: competency_subtasks → competency_subtasks

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_subtasks
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_subtasks
- **Source Script**: `04-migration-scripts/master/competency_subtasks_migration.sql`

- **Legacy Path**: `efr.public.competency_subtasks`
- **New Path**: `smac_master_migration.crewing.competency_subtasks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Competency Subtasks (`competency_subtasks` → `competency_subtasks`)

## Migration Notes

- SAC `sub_task_id` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = sub_task_id`
- Pre-migration duplicate UUID check on SAC `sub_task_id` column
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `task_id` mapped from SAC `task_id` (UUID) via `competency_tasks_id_mapping` (joins `competency_tasks` table)
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0) — Case 1
- Requires `competency_tasks` migrated first

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.competency_subtasks` before insert (full table reload).
- Orchestration dependencies: `competency_tasks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `competency_tasks_id_mapping` | Check i | `legacy_taskid`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `competency_tasks_id_mapping`

- **Purpose**: Check i
- **Output columns**: legacy_taskid, new_id
- **migration.table_mappings**: target_table=competency_tasks

```sql
CREATE TEMP TABLE competency_tasks_id_mapping AS
SELECT DISTINCT
    tm.target_id::text as legacy_taskid,
    ct.id as new_id
FROM migration.table_mappings tm
INNER JOIN crewing.competency_tasks ct ON ct.id = tm.target_id
WHERE tm.target_table = 'competency_tasks'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `sub_task_id` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = sub_task_id` | Preserves SAC `sub_task_id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `task_id` | uuid | `task_id` | uuid | Map via `competency_tasks_id_mapping` on `task_id::text` | Lookup: `migration.table_mappings` + `crewing.competency_tasks`; FK to parent task |
| 4 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 5 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 6 | `guidelines` | text | `guidelines` | text | `TRIM(guidelines)` | Direct copy with whitespace trimmed |
| 7 | `assessment_details` | text | `assessment_details` | text | `TRIM(assessment_details)` | Direct copy with whitespace trimmed |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 10 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 11 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 12 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 13 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 14 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 15 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 16 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 17 | `created_by_id`, `deleted_by_id`, `updated_by_id` | character varying(256) | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs | Standardized SMAC audit structure; no `legacy_id` (sub_task_id preserved as `id`) |

**SMAC columns not migrated:** `tags`, `parent_id`, `archived_at` — no source equivalent in SAC `competency_subtasks`.

**SAC columns not migrated:** `taskid` — not in dblink SELECT (uses `task_id` UUID column instead).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `competency_tasks`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Competency Tasks ID Mapping
**Purpose**: Check i
**Output columns**: `legacy_taskid, new_id`
**migration.table_mappings**: `target_table='competency_tasks'`

```sql
CREATE TEMP TABLE competency_tasks_id_mapping AS
SELECT DISTINCT
    tm.target_id::text as legacy_taskid,
    ct.id as new_id
FROM migration.table_mappings tm
INNER JOIN crewing.competency_tasks ct ON ct.id = tm.target_id
WHERE tm.target_table = 'competency_tasks'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/competency_subtasks_migration.sql`

## Validation

- Run `05-validation/master/competency_subtasks_validation.sql` if available
- Run `06-rollback/master/competency_subtasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
