# Table Mapping: competency_task_applicability → competency_task_applicability

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_task_applicability
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_task_applicability
- **Source Script**: `04-migration-scripts/master/competency_task_applicability_migration.sql`

- **Legacy Path**: `efr.public.competency_task_applicability`
- **New Path**: `smac_master_migration.crewing.competency_task_applicability`

## Business Key

- **Composite Key**: (`task_id`, `rank_id`, `vessel_type_id`)
- **Source (orchestration)**: Competency Task Applicability (`competency_task_applicability` → `competency_task_applicability`)

## Migration Notes

- SAC `task_applicability_id` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = task_applicability_id`
- Pre-migration duplicate UUID check on SAC `task_applicability_id` column
- `task_id` mapped from SAC `task_id` (bigint) via `task_id_mapping` (`migration.table_mappings` where `target_table = 'competency_tasks'`)
- `rank_id` and `vessel_type_id` copied directly as UUIDs (no lookup required)
- `status` derived from `deleted_at`, then `isdeleted`, then `status` varchar — Case 2 hybrid
- Filter: only rows where `id IS NOT NULL` and resolved `task_id` is not NULL
- Requires `competency_tasks` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.competency_task_applicability` before insert (full table reload).
- Orchestration dependencies: `competency_tasks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `task_id_mapping` | Check if any mappings already exist for the given source and target | `legacy_id`, `task_id` | `migration.table_mappings` (see SQL) | - |

### `task_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and target
- **Output columns**: legacy_id, task_id
- **migration.table_mappings**: target_schema=crewing, target_table=competency_tasks

```sql
CREATE TEMP TABLE task_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS task_id
FROM migration.table_mappings
WHERE target_table = 'competency_tasks'
  AND target_schema = 'crewing'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `task_applicability_id` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = task_applicability_id` | Preserves SAC `task_applicability_id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `task_id` | bigint | `task_id` | uuid | Map via `task_id_mapping` on `task_id` bigint | Lookup: `migration.table_mappings` where `target_table = 'competency_tasks'`; rows without mapping excluded |
| 3 | `rank_id` | uuid | `rank_id` | uuid | Direct copy | UUID preserved as-is; no lookup required |
| 4 | `vessel_type_id` | uuid | `vessel_type_id` | uuid | Direct copy | UUID preserved as-is; no lookup required |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `parent_id` | uuid | `NULL` | No parent relationship in SAC |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | `deleted_at`, `isdeleted`, `status` | timestamp, boolean, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule — `deleted_at` takes precedence, then `isdeleted`, then `status` |
| 11 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 12 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 14 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 16 | `created_by_id`, `deleted_by_id`, `updated_by_id` | character varying(256) | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs | Standardized SMAC audit structure; no `legacy_id` (task_applicability_id preserved as `id`) |

**SMAC columns not migrated:** `tags` — no source equivalent in SAC `competency_task_applicability`.

**SAC columns not migrated:** `taskid` — selected in dblink but not used (mapping uses bigint `task_id` instead).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `competency_tasks`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Task ID Mapping
**Purpose**: Check if any mappings already exist for the given source and target
**Output columns**: `legacy_id, task_id`
**migration.table_mappings**: `target_table='competency_tasks'`

```sql
CREATE TEMP TABLE task_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS task_id
FROM migration.table_mappings
WHERE target_table = 'competency_tasks'
  AND target_schema = 'crewing'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/competency_task_applicability_migration.sql`

## Validation

- Run `05-validation/master/competency_task_applicability_validation.sql` if available
- Run `06-rollback/master/competency_task_applicability_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
