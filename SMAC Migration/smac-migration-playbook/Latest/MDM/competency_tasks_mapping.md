# Table Mapping: competency_tasks → competency_tasks

## Overview
- **Legacy Database**: efr
- **Legacy Schema**: public
- **Legacy Table**: competency_tasks
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: competency_tasks
- **Source Script**: `04-migration-scripts/master/competency_tasks_migration.sql`

- **Legacy Path**: `efr.public.competency_tasks`
- **New Path**: `smac_master_migration.crewing.competency_tasks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Competency Tasks (`competency_tasks` → `competency_tasks`)

## Migration Notes

- SAC `taskid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = taskid`
- Pre-migration duplicate UUID check on SAC `taskid` column
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `competency_type_id` mapped from SAC `competency_type` text via `competency_types_id_mapping` (join on name)
- `status` derived from `deleted_at`, then `isdeleted` when `deleted_at` is NULL
- Requires `competency_types` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.competency_tasks` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `competency_types_id_mapping` | FK lookup | `competency_type_name`, `new_id` | - | - |

### `competency_types_id_mapping`

- **Output columns**: competency_type_name, new_id

```sql
CREATE TEMP TABLE competency_types_id_mapping AS
SELECT
    name as competency_type_name,
    id as new_id
FROM crewing.competency_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `taskid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = taskid` | Preserves SAC `taskid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from name; SAC has no `code` column; NOT NULL in SMAC |
| 3 | `competency_type` | text | `competency_type_id` | uuid | Map via `competency_types_id_mapping` on `TRIM(competency_type)` | Lookup: `crewing.competency_types` by name |
| 4 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 5 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 6 | `guidelines` | text | `guidelines` | text | `TRIM(guidelines)` | Direct copy with whitespace trimmed |
| 7 | `assessment_criteria` | text | `assessment_criteria` | text | `TRIM(assessment_criteria)` | Direct copy with whitespace trimmed |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 10 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 11 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 12 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 13 | `deleted_at`, `isdeleted` | timestamp, boolean | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) | `deleted_at` takes precedence; then `isdeleted` when `deleted_at` is NULL |
| 14 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 15 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 16 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 17 | `created_by_id`, `deleted_by_id`, `updated_by_id` | character varying(256) | `audit_info` | jsonb | `migration.build_audit_info()` — created/deleted/updated by IDs | Standardized SMAC audit structure; no `legacy_id` (taskid preserved as `id`) |

**SMAC columns not migrated:** `tags`, `parent_id`, `archived_at` — no source equivalent in SAC `competency_tasks`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `competency_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Competency Types ID Mapping
**Output columns**: `competency_type_name, new_id`

```sql
CREATE TEMP TABLE competency_types_id_mapping AS
SELECT
    name as competency_type_name,
    id as new_id
FROM crewing.competency_types;
```

Full migration context: `04-migration-scripts/master/competency_tasks_migration.sql`

## Validation

- Run `05-validation/master/competency_tasks_validation.sql` if available
- Run `06-rollback/master/competency_tasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
