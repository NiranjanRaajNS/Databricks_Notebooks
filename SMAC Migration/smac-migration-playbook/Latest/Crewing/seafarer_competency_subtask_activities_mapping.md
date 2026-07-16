# Table Mapping: seafarer_competency_subtask_activities → seafarer_competency_subtask_activities

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_subtask_activities
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_subtask_activities
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_subtask_activities_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_subtask_activities`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_subtask_activities`

## Business Key

- **Business Key**: `seafarer_subtask_id`
- **Source (orchestration)**: Seafarer Competency Subtask Activities (`seafarer_competency_subtask_activities` → `seafarer_competency_subtask_activities`)

## Migration Notes

- SAC `id` (uuid) preserved as target `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_task_id` and `seafarer_sub_task_id` mapped via `migration.table_mappings` (`seafarer_competency_tasks`, `seafarer_competency_subtasks`); rows with unmapped FKs are excluded
- `data` (jsonb) transformed from legacy array format to single JSON object (`TaskId`, `Status`, `ApprovedBy`, `ApprovedAt`, `UpdatedAt`); falls back to jsonb-to-text when not array
- Uses `migration.build_audit_info()` with legacy task/subtask IDs in `notes`
- Requires `seafarer_competency_tasks` and `seafarer_competency_subtasks` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_subtask_activities` before insert (full table reload).
- Orchestration dependencies: `seafarer_competency_subtasks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_competency_subtasks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_competency_tasks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_competency_subtasks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_competency_subtasks

```sql
CREATE TEMP TABLE seafarer_competency_subtasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_subtasks'
  AND target_db = current_database();
```

### `seafarer_competency_tasks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_competency_tasks

```sql
CREATE TEMP TABLE seafarer_competency_tasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_tasks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves legacy UUID |
| 2 | `seafarer_task_id` | uuid | `seafarer_task_id` | uuid | Map via `seafarer_competency_tasks_id_mapping` | Required; unmapped rows filtered out |
| 3 | `seafarer_sub_task_id` | uuid | `seafarer_sub_task_id` | uuid | Map via `seafarer_competency_subtasks_id_mapping` | Required; unmapped rows filtered out |
| 4 | `data` | jsonb | `data` | text | LATERAL transform: array → latest element as `{TaskId, Status, ApprovedBy, ApprovedAt, UpdatedAt}`; else jsonb cast to text | Legacy array uses `Id`, `Status`, `VesselId`, `UpdatedAt`, `UpdatedById`, `UpdatedByName` |
| 5 | `status` | text | `status` | text | `TRIM(COALESCE(status, ''))` | NOT NULL; empty string default |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `created_at` | timestamp(6) | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 8 | `updated_at` | timestamp(6) | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 9 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 10 | `deleted_at` | timestamp(6) | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 11 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` — legacy task/subtask IDs in `notes` | Standardized SMAC audit structure |
| 12 | — | — | `name` | text | `NULL` | New optional SMAC field |

**SMAC columns not migrated:** `name` — set to NULL (no source equivalent).

**SAC columns not migrated:** None — all source columns used in mapping or audit_info.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_competency_subtasks`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Competency Subtasks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_competency_subtasks'`

```sql
CREATE TEMP TABLE seafarer_competency_subtasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_subtasks'
  AND target_db = current_database();
```

### 2. Seafarer Competency Tasks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_competency_tasks'`

```sql
CREATE TEMP TABLE seafarer_competency_tasks_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_competency_tasks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_competency_subtask_activities_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_subtask_activities_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_subtask_activities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
