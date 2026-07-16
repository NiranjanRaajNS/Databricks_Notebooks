# Table Mapping: sea_experience_vessel_pool → sea_experience_vessel_pool

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: sea_experience_vessel_pool
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: sea_experience_vessel_pool
- **Source Script**: `04-migration-scripts/crewing/sea_experience_vessel_pool_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.sea_experience_vessel_pool`
- **New Path**: `smac_crewing_migration.shore.sea_experience_vessel_pool`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Sea Experience Vessel Pool (`sea_experience_vessel_pool` → `sea_experience_vessel_pool`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires seafarers, seafarer_sea_experiences, vessel_pools, vessel_pool_mappings to be migrated first (for FK mappings)
- Migrates sea_experience_vessel_pool to shore.sea_experience_vessel_pool. Preserves legacy UUID from source id column using migration.resolve_target_id(). Maps sefarer_uuid (note: typo in source) to seafarer_id via migration.table_mappings. Maps sea_experience_id (bigint) to uuid via mapping table using source table's uuid column. Maps vessel_pool_id and vessel_pool_mappings_id (both uuid) through migration.table_mappings from smac_master_migration database. Requires seafarers, seafarer_sea_experiences, vessel_pools, and vessel_pool_mappings to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.sea_experience_vessel_pool` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_sea_experiences`, `vessel_pools`, `vessel_pool_mappings`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `legacy_seafarer_uuid`, `new_seafarer_id` | `migration.table_mappings` (see SQL) | - |
| `sea_experience_id_mapping` | FK lookup | `legacy_sea_experience_id`, `new_sea_experience_id` | `migration.table_mappings` (see SQL) | `synergy_seafarer` |
| `vessel_pool_id_mapping` | FK lookup | `legacy_vessel_pool_id`, `new_vessel_pool_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_pool_mappings_id_mapping` | FK lookup | `legacy_vessel_pool_mappings_id`, `new_vessel_pool_mappings_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarer_uuid_mapping`

- **Output columns**: legacy_seafarer_uuid, new_seafarer_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    tm.target_id AS legacy_seafarer_uuid,
    tm.target_id AS new_seafarer_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### `sea_experience_id_mapping`

- **Output columns**: legacy_sea_experience_id, new_sea_experience_id
- **migration.table_mappings**: target_table=seafarer_sea_experiences
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE sea_experience_id_mapping AS
SELECT DISTINCT
    sac_se.id AS legacy_sea_experience_id,
    tm.target_id AS new_sea_experience_id
FROM dblink('synergy_seafarer',
    'SELECT id, COALESCE(uuid, NULL::uuid) AS uuid FROM public.sea_experiences WHERE id IS NOT NULL'
) AS sac_se(id bigint, uuid uuid)
JOIN migration.table_mappings tm ON tm.source_id::uuid = sac_se.uuid
WHERE tm.target_table = 'seafarer_sea_experiences'
  AND tm.target_db = current_database()
  AND sac_se.uuid IS NOT NULL;
```

### `vessel_pool_id_mapping`

- **Output columns**: legacy_vessel_pool_id, new_vessel_pool_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_id,
    target_id AS new_vessel_pool_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pools''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

### `vessel_pool_mappings_id_mapping`

- **Output columns**: legacy_vessel_pool_mappings_id, new_vessel_pool_mappings_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_mappings_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_mappings_id,
    target_id AS new_vessel_pool_mappings_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pool_mappings''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'sea_experience_vessel_pool'::VARCHAR(100), s.legacy_id::text, current_database()::text::V... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_map.new_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_map.new_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | sea_experience_id | - | COALESCE(sea_exp_map.new_sea_experience_id, '00000000-0000-0000-0000-000000000000'::uuid) AS sea_experience_id | COALESCE(sea_exp_map.new_sea_experience_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | vessel_pool_id | - | COALESCE(vessel_pool_map.new_vessel_pool_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_pool_id | COALESCE(vessel_pool_map.new_vessel_pool_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | vessel_pool_mappings_id | - | COALESCE(vessel_pool_mappings_map.new_vessel_pool_mappings_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_pool_mappings_id | COALESCE(vessel_pool_mappings_map.new_vessel_pool_mappings_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | start_date | - | start_date | - | s.start_date AS start_date | s.start_date |
| 7 | end_date | - | end_date | - | s.end_date AS end_date | s.end_date |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 10 | legacy_updated_at | - | updated_at | - | COALESCE(s.legacy_updated_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, NOW()) |
| 11 | - | - | archived_at | - | NULL | NULL::timestamp |
| 12 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 13 | created_by_id, deleted_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN s.created_by_id IS NOT NULL THEN s.created_by_id::varchar ELSE NULL END, CASE WHEN s.deleted_by_id IS NOT NULL THEN s.deleted_by_id::varcha... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `legacy_seafarer_uuid, new_seafarer_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    tm.target_id AS legacy_seafarer_uuid,
    tm.target_id AS new_seafarer_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### 2. Sea Experience ID Mapping
**Output columns**: `legacy_sea_experience_id, new_sea_experience_id`
**migration.table_mappings**: `target_table='seafarer_sea_experiences'`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE sea_experience_id_mapping AS
SELECT DISTINCT
    sac_se.id AS legacy_sea_experience_id,
    tm.target_id AS new_sea_experience_id
FROM dblink('synergy_seafarer',
    'SELECT id, COALESCE(uuid, NULL::uuid) AS uuid FROM public.sea_experiences WHERE id IS NOT NULL'
) AS sac_se(id bigint, uuid uuid)
JOIN migration.table_mappings tm ON tm.source_id::uuid = sac_se.uuid
WHERE tm.target_table = 'seafarer_sea_experiences'
  AND tm.target_db = current_database()
  AND sac_se.uuid IS NOT NULL;
```

### 3. Vessel Pool ID Mapping
**Output columns**: `legacy_vessel_pool_id, new_vessel_pool_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_id,
    target_id AS new_vessel_pool_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pools''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

### 4. Vessel Pool Mappings ID Mapping
**Output columns**: `legacy_vessel_pool_mappings_id, new_vessel_pool_mappings_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_mappings_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_mappings_id,
    target_id AS new_vessel_pool_mappings_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pool_mappings''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/sea_experience_vessel_pool_migration.sql`

## Validation

- Run `05-validation/crewing/sea_experience_vessel_pool_validation.sql` if available
- Run `06-rollback/crewing/sea_experience_vessel_pool_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
