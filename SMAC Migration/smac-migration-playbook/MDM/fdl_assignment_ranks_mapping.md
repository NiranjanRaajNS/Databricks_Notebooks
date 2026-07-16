# Table Mapping: fdl_assignment_ranks → fdl_assignment_ranks

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_assignment_ranks
- **Source Script**: `04-migration-scripts/master/fdl_assignment_ranks_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_fdl.seafarer_rank_ids`
- **New Path**: `smac_master_migration.vessel.fdl_assignment_ranks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## Migration Notes

- Generates new UUIDs for id (junction table pattern)
- Unnests seafarer_rank_ids array to create one row per rank
- Links to fdl_role_assignments via vessel_fdl.identifier (assignment_id)
- Uses seafarer_rank_id UUID directly from array (no mapping needed)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.fdl_role_assignments to be migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_assignment_ranks` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_rank_source_id`, `new_rank_id` | `synergy_master.?.ranks` → `?.?.ranks` | - |
| `seafarer_rank_id_mapping` | FK lookup | `legacy_seafarer_rank_identifier`, `new_seafarer_rank_id` | - | - |

### `ranks_id_mapping`

- **Output columns**: legacy_rank_source_id, new_rank_id
- **migration.table_mappings**: source_db=synergy_master, source_table=ranks, target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_source_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND source_table = 'ranks'
  AND source_db = 'synergy_master'
  AND target_db = current_database();
```

### `seafarer_rank_id_mapping`

- **Output columns**: legacy_seafarer_rank_identifier, new_seafarer_rank_id

```sql
CREATE TEMP TABLE seafarer_rank_id_mapping AS
SELECT DISTINCT
    rld.legacy_rank_identifier::text AS legacy_seafarer_rank_identifier,
    COALESCE(

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_identifier::text),

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_id::text),
        NULL
    ) AS new_seafarer_rank_id
FROM ranks_legacy_data rld;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_vessel_fdl_identifier, legacy_seafarer_rank_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_fdl'::VARCHAR(100), (s.legacy_vessel_fdl_identifier || '|' || s.legacy_seafarer_rank... |
| 2 | id | - | assignment_id | - | fra.id AS assignment_id | fra.id |
| 3 | derived | - | seafarer_rank_id | - | rank_map.new_seafarer_rank_id AS seafarer_rank_id | rank_map.new_seafarer_rank_id |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | legacy_create_at | - | created_at | - | COALESCE(s.legacy_create_at, NOW()) AS created_at | COALESCE(s.legacy_create_at, NOW()) |
| 8 | legacy_update_at, legacy_create_at | - | updated_at | - | COALESCE(s.legacy_update_at, s.legacy_create_at, NOW()) AS updated_at | COALESCE(s.legacy_update_at, s.legacy_create_at, NOW()) |
| 9 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 10 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 11 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 12 | derived | - | tags | - | NULL AS tags | NULL |
| 13 | level | - | level | - | COALESCE(fra.level, 0) AS level | COALESCE(fra.level, 0) |
| 14 | legacy_deleted_at, legacy_status | - | status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(s.legacy_status)) = 'ACTIVE' OR TRIM(s.legacy_status) = '0' THEN 0 WHEN UPPE... | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(s.legacy_status)) = 'ACTIVE' OR TRIM(s.legacy_status) = '0' THEN 0 WHEN UPPE... |
| 15 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 16 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fdl_role_assignments`
- `vessel.fdl_role_assignments`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_rank_source_id, new_rank_id`
**migration.table_mappings**: `ranks` → `ranks` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_source_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND source_table = 'ranks'
  AND source_db = 'synergy_master'
  AND target_db = current_database();
```

### 2. Seafarer Rank ID Mapping
**Output columns**: `legacy_seafarer_rank_identifier, new_seafarer_rank_id`

```sql
CREATE TEMP TABLE seafarer_rank_id_mapping AS
SELECT DISTINCT
    rld.legacy_rank_identifier::text AS legacy_seafarer_rank_identifier,
    COALESCE(

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_identifier::text),

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_id::text),
        NULL
    ) AS new_seafarer_rank_id
FROM ranks_legacy_data rld;
```

Full migration context: `04-migration-scripts/master/fdl_assignment_ranks_migration.sql`

## Validation

- Run `05-validation/master/fdl_assignment_ranks_validation.sql` if available
- Run `06-rollback/master/fdl_assignment_ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
