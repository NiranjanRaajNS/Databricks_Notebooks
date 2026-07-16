# Table Mapping: reliefs → relief_remarks

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: reliefs
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: relief_remarks
- **Source Script**: `04-migration-scripts/crewing/relief_remarks_migration.sql`

- **Legacy Path**: `synergy_manning.public.reliefs`
- **New Path**: `smac_crewing_migration.shore.relief_remarks`

## Business Key

- **Business Key**: `relief_id`
- **Source (orchestration)**: Relief Remarks (`reliefs` → `relief_remarks`)

## Migration Notes

- Generate new UUID for id (source table has bigint id)
- Map relief_id (bigint) → relief_id (uuid) via reliefs mapping table (map to relief.uuid)
- Map created_by_id (varchar) → created_by_id (uuid)
- Uses standardized SMAC audit_info structure
- Migrates relief_remarks from reliefs table. Extracts comment from onsigner_remarks JSONB. Generates new UUIDs for id column (source has bigint, target has uuid). Maps relief_id (bigint) → relief_id (uuid) via seafarer_reliefs mapping table (map to relief.uuid). Maps created_by_id (varchar) to uuid. Uses standardized SMAC audit_info structure. Creates one remark record per relief that has onsigner_remarks JSONB data. Requires seafarer_reliefs table to be migrated first.

## Special Considerations

- Extract comment from onsigner_remarks JSONB
- Script performs `TRUNCATE TABLE shore.relief_remarks` before insert (full table reload).
- Orchestration dependencies: `seafarer_reliefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relief_id_mapping` | Check if any mappings already exist | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `relief_id_mapping`

- **Purpose**: Check if any mappings already exist
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarer_reliefs

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'reliefs'::VARCHAR(100), LEFT(legacy_data.id::text || '|' || remark_obj.ordinality::text, 1... |
| 2 | derived | - | relief_id | - | COALESCE(relief_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS relief_id | COALESCE(relief_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | comment | - | COALESCE( remark_obj.remark_json->>'comment', remark_obj.remark_json->>'remarks', remark_obj.remark_json->>'text', remark_obj.remark_json->>'note', '' ) AS comment | COALESCE( remark_obj.remark_json->>'comment', remark_obj.remark_json->>'remarks', remark_obj.remark_json->>'text', remark_obj.remark_json->>'note', '' ) |
| 4 | created_by_id | - | created_by_id | - | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 7 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 8 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 9 | deleted_at | - | deleted_at | - | COALESCE(legacy_data.deleted_at, NULL) AS deleted_at | COALESCE(legacy_data.deleted_at, NULL) |
| 10 | created_by_id, updated_by_id, id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relief ID Mapping
**Purpose**: Check if any mappings already exist
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarer_reliefs'`

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/relief_remarks_migration.sql`

## Validation

- Run `05-validation/crewing/relief_remarks_validation.sql` if available
- Run `06-rollback/crewing/relief_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
