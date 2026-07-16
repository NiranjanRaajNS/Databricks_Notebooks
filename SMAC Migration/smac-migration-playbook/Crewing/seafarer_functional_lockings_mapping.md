# Table Mapping: seafarer_functional_lockings → seafarer_functional_lockings

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_functional_lockings
- **New Database**: smac_master_migration
- **New Schema**: shore
- **New Table**: seafarer_functional_lockings
- **Source Script**: `04-migration-scripts/crewing/seafarer_functional_lockings_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_functional_lockings`
- **New Path**: `smac_master_migration.shore.seafarer_functional_lockings`

## Business Key

- **Composite Key**: (`seafarer_id`, `id`)
- **Source (orchestration)**: Seafarer Functional Lockings (`seafarer_functional_lockings` → `seafarer_functional_lockings`)

## Migration Notes

- Migrates seafarer_functional_lockings from synergy_seafarer.public.seafarer_functional_lockings to smac_master_migration.shore.seafarer_functional_lockings. Preserves legacy UUID (id) as target id (Pattern A). Maps seafarer_id from bigint to uuid via migration.table_mappings from smac_crewing_migration database (seafarers table). Parses created_by_id and updated_by_id as UUID if valid format, otherwise NULL. stage_code set to NULL (not in source). payload mapped directly with fallback to empty JSONB. Uses standardized SMAC audit_info structure via migration.build_audit_info(). Requires seafarers table to be migrated first in crewing database.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_functional_lockings` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_functional_lockings'::VARCHAR(100), legacy_data.id::text, current_database()::te... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | - | - | stage_code | - | NULL | NULL::varchar(50) |
| 4 | payload | - | payload | - | COALESCE(legacy_data.payload, '{}'::jsonb) as payload | COALESCE(legacy_data.payload, '{}'::jsonb) |
| 5 | created_by_id | - | created_by | - | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... |
| 6 | updated_by_id | - | updated_by | - | CASE WHEN legacy_data.updated_by_id IS NOT NULL AND legacy_data.updated_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.updated_by_id::... | CASE WHEN legacy_data.updated_by_id IS NOT NULL AND legacy_data.updated_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.updated_by_id::... |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 9 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 10 | - | - | archived_at | - | NULL | NULL::timestamp |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_functional_lockings_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_functional_lockings_validation.sql` if available
- Run `06-rollback/crewing/seafarer_functional_lockings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
