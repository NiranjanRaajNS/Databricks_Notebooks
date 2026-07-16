# Table Mapping: seafarer_wellbeing_activity_logs → seafarer_wellbeing_activity_logs

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_wellbeing_activity_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_wellbeing_activity_logs_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Wellbeing Activity Logs (`seafarer_wellbeing_activity_logs` → `seafarer_wellbeing_activity_logs`)

## Migration Notes

- Preserves legacy UUID id via migration.resolve_target_id()
- Maps wellbeing_id using migration.table_mappings from seafarer_wellbeing migration
- Converts deleted_by_id (varchar) to uuid when valid
- audit_info: same migration.build_audit_info() pattern as seafarer_wellbeing_assignees_migration.sql,
- Migrates seafarer_wellbeing_activity_logs from synergy_seafarer.public.seafarer_wellbeing_activity_logs to smac_crewing_migration.shore.seafarer_wellbeing_activity_logs. Preserves legacy UUID id via migration.resolve_target_id(). Maps wellbeing_id using migration.table_mappings from seafarer_wellbeing migration. Converts deleted_by_id/created_by_id/updated_by_id to UUID in audit_info when valid; sets tenant_id from constants.

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_wellbeing_activity_logs'::VARCHAR(100), legacy_data.id::text, current_database()... |
| 2 | wellbeing_id | - | wellbeing_id | - | COALESCE(wellbeing_map.new_id, legacy_data.wellbeing_id) AS wellbeing_id | COALESCE(wellbeing_map.new_id, legacy_data.wellbeing_id) |
| 3 | action_type | - | action_type | - | COALESCE(legacy_data.action_type, '')::text AS action_type | COALESCE(legacy_data.action_type, '')::text |
| 4 | action_details | - | action_details | - | legacy_data.action_details AS action_details | legacy_data.action_details |
| 5 | deleted_by_id | - | deleted_by_id | - | CASE WHEN legacy_data.deleted_by_id IS NOT NULL AND TRIM(legacy_data.deleted_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN LOWER(TRIM(legacy_da... | CASE WHEN legacy_data.deleted_by_id IS NOT NULL AND TRIM(legacy_data.deleted_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN LOWER(TRIM(legacy_da... |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 11 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | ( migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{1... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
