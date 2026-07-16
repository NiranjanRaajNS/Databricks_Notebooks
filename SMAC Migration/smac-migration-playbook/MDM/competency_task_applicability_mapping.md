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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates competency_task_applicability junction table. Preserves task_applicability_id UUID as id if available, otherwise generates new UUID. Maps TaskId from taskid (UUID) directly, or from task_id (bigint) via migration.table_mappings. Maps RankId and VesselTypeId from UUID columns directly. Requires competency_tasks table to be migrated first.

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
| 1 | id, task_applicability_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'efr'::VARCHAR(100), 'public'::VARCHAR(100), 'competency_task_applicability'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | task_id | - | task_mapping.task_id AS task_id | task_mapping.task_id |
| 3 | rank_id | - | rank_id | - | legacy_data.rank_id AS rank_id | legacy_data.rank_id |
| 4 | vessel_type_id | - | vessel_type_id | - | legacy_data.vessel_type_id AS vessel_type_id | legacy_data.vessel_type_id |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at, isdeleted, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.isdeleted = true THEN 3 ELSE CASE WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN ... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.isdeleted = true THEN 3 ELSE CASE WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN ... |
| 11 | derived | - | level | - | 0 AS level | 0 |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | created_by_id, deleted_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
