# Table Mapping: seafarer_wellbeing_activity_logs → seafarer_wellbeing_activity_logs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_wellbeing_activity_logs
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_wellbeing_activity_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_wellbeing_activity_logs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_wellbeing_activity_logs`
- **New Path**: `smac_crewing_migration.shore.seafarer_wellbeing_activity_logs`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Wellbeing Activity Logs (`seafarer_wellbeing_activity_logs` → `seafarer_wellbeing_activity_logs`, group: SeafarerWellbeing)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`; pre-migration duplicate UUID check
- `wellbeing_id` mapped via `wellbeing_id_mapping` from `seafarer_wellbeing` table_mappings; fallback legacy UUID
- `deleted_by_id` (varchar) cast to uuid when valid UUID regex; else NULL
- Active assignee UUID from `wellbeing_assignee_mapping` stored in `audit_info.assigned_to`
- Filter: `id IS NOT NULL AND wellbeing_id IS NOT NULL`; all records including deleted migrated
- Requires `seafarer_wellbeing` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_wellbeing_activity_logs` before insert (full table reload).
- Orchestration dependencies: `seafarer_wellbeing`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wellbeing_id_mapping` | Clear existing mappi | `legacy_id`, `new_id` | `synergy_seafarer.public.seafarer_wellbeing` → `?.shore.seafarer_wellbeing` | - |
| `wellbeing_assignee_mapping` | FK lookup | `legacy_wellbeing_id`, `assignee_row_id`, `assignee_uuid` | - | `synergy_seafarer` |

### `wellbeing_id_mapping`

- **Purpose**: Clear existing mappi
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=seafarer_wellbeing, target_schema=shore, target_table=seafarer_wellbeing

```sql
CREATE TEMP TABLE wellbeing_id_mapping AS
SELECT
    source_id::uuid AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_db = current_database()
  AND target_schema = 'shore'
  AND target_table = 'seafarer_wellbeing'
  AND source_db = 'synergy_seafarer'
  AND source_schema = 'public'
  AND source_table = 'seafarer_wellbeing'
  AND source_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### `wellbeing_assignee_mapping`

- **Output columns**: legacy_wellbeing_id, assignee_row_id, assignee_uuid
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE wellbeing_assignee_mapping AS
SELECT DISTINCT ON (legacy_assignees.wellbeing_id)
    legacy_assignees.wellbeing_id AS legacy_wellbeing_id,
    legacy_assignees.id AS assignee_row_id,
    legacy_assignees.assignee_uuid AS assignee_uuid
FROM dblink(
    'synergy_seafarer',
    'SELECT id, wellbeing_id, assignee_uuid, assignee_type, is_active_assignee, updated_at, created_at
     FROM public.seafarer_wellbeing_assignees
     WHERE wellbeing_id IS NOT NULL
       AND assignee_uuid IS NOT NULL
       AND COALESCE(is_active_assignee, false) = true
       AND UPPER(TRIM(COALESCE(assignee_type, ''''))) IN (''ASSIGN'', ''REASSIGN'')'
) AS legacy_assignees(
    id uuid,
    wellbeing_id uuid,
    assignee_uuid uuid,
    assignee_type varchar,
    is_active_assignee boolean,
    updated_at timestamp,
    created_at timestamp
)
ORDER BY
    legacy_assignees.wellbeing_id,
    legacy_assignees.updated_at DESC NULLS LAST,
    legacy_assignees.created_at DESC NULLS LAST,
    legacy_assignees.id DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `wellbeing_id` | uuid | `wellbeing_id` | uuid | Map via `wellbeing_id_mapping`; fallback legacy UUID | |
| 3 | `action_type` | character varying | `action_type` | text | `COALESCE(action_type, '')` | |
| 4 | `action_details` | text | `action_details` | text | Direct copy | |
| 5 | `deleted_by_id` | character varying | `deleted_by_id` | uuid | UUID regex → cast; else NULL | Also in `audit_info.deleted_by` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 9 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 11 | `created_by_id`, `updated_by_id`, names | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — UUID regex for IDs; names in `notes` | |
| 12 | (assignees table) | uuid | `audit_info.assigned_to` | uuid | Active ASSIGN/REASSIGN assignee from `wellbeing_assignee_mapping` | |

**SMAC columns not migrated:** `archived_at` — always NULL.

**SAC columns not migrated:** None in dblink SELECT — all selected columns used.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_wellbeing`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wellbeing ID Mapping
**Purpose**: Clear existing mappi
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `seafarer_wellbeing` → `seafarer_wellbeing` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE wellbeing_id_mapping AS
SELECT
    source_id::uuid AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_db = current_database()
  AND target_schema = 'shore'
  AND target_table = 'seafarer_wellbeing'
  AND source_db = 'synergy_seafarer'
  AND source_schema = 'public'
  AND source_table = 'seafarer_wellbeing'
  AND source_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### 2. Wellbeing Assignee ID Mapping
**Output columns**: `legacy_wellbeing_id, assignee_row_id, assignee_uuid`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE wellbeing_assignee_mapping AS
SELECT DISTINCT ON (legacy_assignees.wellbeing_id)
    legacy_assignees.wellbeing_id AS legacy_wellbeing_id,
    legacy_assignees.id AS assignee_row_id,
    legacy_assignees.assignee_uuid AS assignee_uuid
FROM dblink(
    'synergy_seafarer',
    'SELECT id, wellbeing_id, assignee_uuid, assignee_type, is_active_assignee, updated_at, created_at
     FROM public.seafarer_wellbeing_assignees
     WHERE wellbeing_id IS NOT NULL
       AND assignee_uuid IS NOT NULL
       AND COALESCE(is_active_assignee, false) = true
       AND UPPER(TRIM(COALESCE(assignee_type, ''''))) IN (''ASSIGN'', ''REASSIGN'')'
) AS legacy_assignees(
    id uuid,
    wellbeing_id uuid,
    assignee_uuid uuid,
    assignee_type varchar,
    is_active_assignee boolean,
    updated_at timestamp,
    created_at timestamp
)
ORDER BY
    legacy_assignees.wellbeing_id,
    legacy_assignees.updated_at DESC NULLS LAST,
    legacy_assignees.created_at DESC NULLS LAST,
    legacy_assignees.id DESC;
```

Full migration context: `04-migration-scripts/crewing/seafarer_wellbeing_activity_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_wellbeing_activity_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_wellbeing_activity_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
