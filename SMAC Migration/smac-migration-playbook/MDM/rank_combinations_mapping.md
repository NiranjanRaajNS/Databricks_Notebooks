# Table Mapping: rank_combinations → rank_combinations

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combinations
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: rank_combinations
- **Source Script**: `04-migration-scripts/master/rank_combinations_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combinations`
- **New Path**: `smac_master_migration.crewing.rank_combinations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Rank Combinations (`rank_combinations` → `rank_combinations`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_combinations preserving structure. Uses migration.resolve_target_id() for idempotent UUID generation. Maps group_id (bigint) to UUID via combination_matrix_groups lookup. Maps is_active boolean and deleted_at to status integer (Case 3 pattern). Generates code from name if not available. Uses standardized SMAC audit_info structure with legacy_id. Requires combination_matrix_groups to be migrated first.

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Script performs `TRUNCATE TABLE crewing.rank_combinations` before insert (full table reload).
- Orchestration dependencies: `combination_matrix_groups`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | Check if any mappings already exist for the given source and targe | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `ranks_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and targe
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rank_combinations'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | primary_rank_id | - | primary_rank_map.new_id as primary_rank_id | primary_rank_map.new_id |
| 3 | derived | - | secondary_rank_id | - | secondary_rank_map.new_id as secondary_rank_id | secondary_rank_map.new_id |
| 4 | derived | - | level | - | 0::integer as level | 0::integer |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 9 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 10 | - | - | archived_at | - | NULL | NULL::timestamp |
| 11 | created_by, deleted_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by IS NOT NULL AND TRIM(legacy_data.created_by) <> '' THEN TRIM(legacy_data.created_by) ELSE NULL END::varchar, CASE WH... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Purpose**: Check if any mappings already exist for the given source and targe
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/rank_combinations_migration.sql`

## Validation

- Run `05-validation/master/rank_combinations_validation.sql` if available
- Run `06-rollback/master/rank_combinations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
