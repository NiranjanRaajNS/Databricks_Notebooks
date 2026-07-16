# Table Mapping: rank_combination_vessel_mappings → combination_matrix_vessel

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combination_vessel_mappings
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: combination_matrix_vessel
- **Source Script**: `04-migration-scripts/master/combination_matrix_vessel_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combination_vessel_mappings`
- **New Path**: `smac_master_migration.crewing.combination_matrix_vessel`

## Business Key

- **Composite Key**: (`matrix_id`, `vessel_id`)
- **Source (orchestration)**: Combination Matrix Vessel (`rank_combination_vessel_mappings` → `combination_matrix_vessel`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_combination_vessel_mappings to combination_matrix_vessel. Uses migration.resolve_target_id() with composite key (matrix_id|vessel_id) for idempotent UUID generation. Maps matrix_id (bigint) to UUID via combination_matrix lookup. Maps vessel_id (bigint) to UUID via vessel.vessels lookup. Maps is_active boolean and deleted_at to status integer (Case 3 pattern). Uses standardized SMAC audit_info structure with legacy_id. Requires combination_matrix and vessel.vessels to be migrated first.

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Source table vessel_type_mapping_id is UUID (direct FK, not bigint)
- Source table vessel_id is integer (not bigint)
- Script performs `TRUNCATE TABLE crewing.combination_matrix_vessel` before insert (full table reload).
- Orchestration dependencies: `combination_matrix`, `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=vessel, target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_schema = 'vessel'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rank_combination_vessel_mappings'::VARCHAR(100), legacy_data.id::text, current_database()::... |
| 2 | derived | - | vessel_id | - | vessel_map.new_id as vessel_id | vessel_map.new_id |
| 3 | vessel_type_mapping_id | - | vessel_type_mapping_id | - | legacy_data.vessel_type_mapping_id as vessel_type_mapping_id | legacy_data.vessel_type_mapping_id |
| 4 | derived | - | level | - | 0::integer as level | 0::integer |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 7 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 8 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_schema = 'vessel'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/combination_matrix_vessel_migration.sql`

## Validation

- Run `05-validation/master/combination_matrix_vessel_validation.sql` if available
- Run `06-rollback/master/combination_matrix_vessel_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
