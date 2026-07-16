# Table Mapping: seafarer_activity_log_sub_types → activity_log_sub_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_log_sub_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: activity_log_sub_types
- **Source Script**: `04-migration-scripts/master/activity_log_sub_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_log_sub_types`
- **New Path**: `smac_master_migration.crewing.activity_log_sub_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Activity Log Sub Types (`seafarer_activity_log_sub_types` → `activity_log_sub_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_activity_log_sub_types preserving identifier UUID as id if available

## Special Considerations

- Excludes: Sign On and Sign Off (not migrated; not inserted).
- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.activity_log_sub_types` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `activity_type_id_mapping` | FK lookup | `legacy_activity_type_id`, `target_activity_type_id` | `synergy_seafarer.public.seafarer_activity_log_types` → `?.crewing.activity_log_types` | - |

### `activity_type_id_mapping`

- **Output columns**: legacy_activity_type_id, target_activity_type_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=seafarer_activity_log_types, target_schema=crewing, target_table=activity_log_types

```sql
CREATE TEMP TABLE activity_type_id_mapping AS
SELECT
    tm.source_id::uuid as legacy_activity_type_id,
    tm.target_id as target_activity_type_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'seafarer_activity_log_types'
  AND tm.target_db = current_database()
  AND tm.target_schema = 'crewing'
  AND tm.target_table = 'activity_log_types';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_activity_log_sub_types'::VARCHAR(100), legacy_data.id::text, current_database():... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | COALESCE(TRIM(legacy_data.description), NULL) as description | COALESCE(TRIM(legacy_data.description), NULL) |
| 5 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | '00000000-0000-0000-0000-000000000000'::uuid as parent_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true THEN 0 WHEN legacy_data.is_active = false THEN 2 ... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true THEN 0 WHEN legacy_data.is_active = false THEN 2 ... |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 17 | - | - | tags | - | NULL | NULL::text[] |
| 18 | derived | - | activity_type_id | - | COALESCE( at_map.target_activity_type_id, (SELECT id FROM crewing.activity_log_types ORDER BY created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) as activity_typ... | COALESCE( at_map.target_activity_type_id, (SELECT id FROM crewing.activity_log_types ORDER BY created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Activity Type ID Mapping
**Output columns**: `legacy_activity_type_id, target_activity_type_id`
**migration.table_mappings**: `seafarer_activity_log_types` → `activity_log_types` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE activity_type_id_mapping AS
SELECT
    tm.source_id::uuid as legacy_activity_type_id,
    tm.target_id as target_activity_type_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'seafarer_activity_log_types'
  AND tm.target_db = current_database()
  AND tm.target_schema = 'crewing'
  AND tm.target_table = 'activity_log_types';
```

Full migration context: `04-migration-scripts/master/activity_log_sub_types_migration.sql`

## Validation

- Run `05-validation/master/activity_log_sub_types_validation.sql` if available
- Run `06-rollback/master/activity_log_sub_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
