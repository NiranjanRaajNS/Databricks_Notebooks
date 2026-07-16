# Table Mapping: positions → positions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: positions
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: positions
- **Source Script**: `04-migration-scripts/master/positions_migration.sql`

- **Legacy Path**: `synergy_master.public.positions`
- **New Path**: `smac_master_migration.public.positions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Positions (`positions` → `positions`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.positions` before insert (full table reload).
- Orchestration dependencies: `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | - |

### `ranks_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'positions'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'pu... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | short_code | - | code | - | COALESCE(NULLIF(UPPER(TRIM(legacy_data.short_code)), ''), '') as code | COALESCE(NULLIF(UPPER(TRIM(legacy_data.short_code)), ''), '') |
| 4 | derived | - | rank_id | - | rm.new_rank_id as rank_id | rm.new_rank_id |
| 5 | short_code | - | engagement_type | - | CASE WHEN rm.new_rank_id = (SELECT id FROM public.ranks WHERE LOWER(TRIM(name)) = LOWER('Supernumerary') LIMIT 1) THEN 2 WHEN UPPER(TRIM(legacy_data.short_code)) = 'FS' THEN 1 W... | CASE WHEN rm.new_rank_id = (SELECT id FROM public.ranks WHERE LOWER(TRIM(name)) = LOWER('Supernumerary') LIMIT 1) THEN 2 WHEN UPPER(TRIM(legacy_data.short_code)) = 'FS' THEN 1 W... |
| 6 | position | - | level | - | COALESCE(legacy_data.position, 0) as level | COALESCE(legacy_data.position, 0) |
| 7 | derived | - | description | - | NULL as description | NULL |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.is_active::text)) = 'ACTIVE' OR TRIM(legacy_data.is_act... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.is_active::text)) = 'ACTIVE' OR TRIM(legacy_data.is_act... |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 16 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) <> '' AND TRIM(legacy_data.created_by_id) ~* '^[0-9a-f]{8}-[0-9a-... |
| 17 | short_code, name | - | tags | - | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT COALESCE(NULLIF(UPPER(TRIM(legacy_data.short_code)), ''), '') AS tag WHERE COALESCE(NULLIF(UPPER(TRIM(legacy_data.sho... | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT COALESCE(NULLIF(UPPER(TRIM(legacy_data.short_code)), ''), '') AS tag WHERE COALESCE(NULLIF(UPPER(TRIM(legacy_data.sho... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/positions_migration.sql`

## Validation

- Run `05-validation/master/positions_validation.sql` if available
- Run `06-rollback/master/positions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
