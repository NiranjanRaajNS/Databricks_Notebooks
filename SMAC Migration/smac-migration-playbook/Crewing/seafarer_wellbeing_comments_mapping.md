# Table Mapping: seafarer_wellbeing_comments → seafarer_wellbeing_comments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_wellbeing_comments
- **Source Script**: `04-migration-scripts/crewing/seafarer_wellbeing_comments_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Wellbeing Comments (`seafarer_wellbeing_comments` → `seafarer_wellbeing_comments`)

## Migration Notes

- Preserves legacy UUID id via migration.resolve_target_id()
- Maps wellbeing_id using migration.table_mappings from seafarer_wellbeing migration
- Converts deleted_by_id (varchar) to uuid when valid
- Migrates seafarer_wellbeing_comments from synergy_seafarer.public.seafarer_wellbeing_comments to smac_crewing_migration.shore.seafarer_wellbeing_comments. Preserves legacy UUID id via migration.resolve_target_id(). Maps wellbeing_id using migration.table_mappings from seafarer_wellbeing migration. Migrates comment_text and comment_type, converts deleted_by_id/created_by_id/updated_by_id to UUID in audit_info when valid, and sets tenant_id from constants.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_wellbeing_comments` before insert (full table reload).
- Orchestration dependencies: `seafarer_wellbeing`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wellbeing_id_mapping` | Check if any map | `legacy_id`, `new_id` | `synergy_seafarer.public.seafarer_wellbeing` → `?.shore.seafarer_wellbeing` | - |

### `wellbeing_id_mapping`

- **Purpose**: Check if any map
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_wellbeing_comments'::VARCHAR(100), legacy_data.id::text, current_database()::tex... |
| 2 | wellbeing_id | - | wellbeing_id | - | COALESCE(wellbeing_map.new_id, legacy_data.wellbeing_id) AS wellbeing_id | COALESCE(wellbeing_map.new_id, legacy_data.wellbeing_id) |
| 3 | comment_text | - | comment_text | - | legacy_data.comment_text AS comment_text | legacy_data.comment_text |
| 4 | comment_type | - | comment_type | - | COALESCE(legacy_data.comment_type, '')::text AS comment_type | COALESCE(legacy_data.comment_type, '')::text |
| 5 | deleted_by_id | - | deleted_by_id | - | CASE WHEN legacy_data.deleted_by_id IS NOT NULL AND TRIM(legacy_data.deleted_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN LOWER(TRIM(legacy_da... | CASE WHEN legacy_data.deleted_by_id IS NOT NULL AND TRIM(legacy_data.deleted_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN LOWER(TRIM(legacy_da... |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 11 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wellbeing ID Mapping
**Purpose**: Check if any map
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

Full migration context: `04-migration-scripts/crewing/seafarer_wellbeing_comments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_wellbeing_comments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_wellbeing_comments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
