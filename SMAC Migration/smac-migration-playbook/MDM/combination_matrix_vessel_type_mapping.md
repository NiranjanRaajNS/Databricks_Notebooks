# Table Mapping: rank_combination_vessel_type_mappings → combination_matrix_vessel_type

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combination_vessel_type_mappings
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: combination_matrix_vessel_type
- **Source Script**: `04-migration-scripts/master/combination_matrix_vessel_type_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combination_vessel_type_mappings`
- **New Path**: `smac_master_migration.crewing.combination_matrix_vessel_type`

## Business Key

- **Composite Key**: (`matrix_id`, `vessel_type_id`)
- **Source (orchestration)**: Combination Matrix Vessel Type (`rank_combination_vessel_type_mappings` → `combination_matrix_vessel_type`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_combination_vessel_type_mappings to combination_matrix_vessel_type. Uses migration.resolve_target_id() with composite key (matrix_id|vessel_type_id) for idempotent UUID generation. Maps matrix_id (bigint) to UUID via combination_matrix lookup. Maps vessel_type_id (bigint) to UUID via vessel.categories lookup. Maps is_active boolean and deleted_at to status integer (Case 3 pattern). Uses standardized SMAC audit_info structure with legacy_id. Requires combination_matrix and vessel.categories to be migrated first.

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Source table combination_matrix_id is UUID (not bigint)
- Source table vessel_type_id is integer (not bigint)
- Script performs `TRUNCATE TABLE crewing.combination_matrix_vessel_type` before insert (full table reload).
- Orchestration dependencies: `combination_matrix`, `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=vessel, target_table=categories

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_schema = 'vessel'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rank_combination_vessel_type_mappings'::VARCHAR(100), legacy_data.id::text, current_databas... |
| 2 | combination_matrix_id | - | combination_matrix_id | - | legacy_data.combination_matrix_id as combination_matrix_id | legacy_data.combination_matrix_id |
| 3 | derived | - | vessel_type_id | - | vessel_type_map.new_id as vessel_type_id | vessel_type_map.new_id |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
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

### 1. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='categories'`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_schema = 'vessel'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/combination_matrix_vessel_type_migration.sql`

## Validation

- Run `05-validation/master/combination_matrix_vessel_type_validation.sql` if available
- Run `06-rollback/master/combination_matrix_vessel_type_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
