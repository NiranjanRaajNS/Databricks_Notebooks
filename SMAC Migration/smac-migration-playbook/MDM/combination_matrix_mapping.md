# Table Mapping: rank_combination_matrix_mappings → combination_matrix

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combination_matrix_mappings
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: combination_matrix
- **Source Script**: `04-migration-scripts/master/combination_matrix_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combination_matrix_mappings`
- **New Path**: `smac_master_migration.crewing.combination_matrix`

## Business Key

- **Composite Key**: (`combination_id`, `rank_id`)
- **Source (orchestration)**: Combination Matrix (`rank_combination_matrix_mappings` → `combination_matrix`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_combination_matrix_mappings to combination_matrix. Uses migration.resolve_target_id() with composite key (combination_id|rank_id) for idempotent UUID generation. Maps combination_id and rank_id (bigint) to UUIDs via lookup tables. Maps is_active boolean and deleted_at to status integer (Case 3 pattern). Uses standardized SMAC audit_info structure with legacy_id. Requires rank_combinations and ranks to be migrated first.

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Source table combination_matrix_id and rank_combination_id are UUIDs (not bigint)
- Script performs `TRUNCATE TABLE crewing.combination_matrix` before insert (full table reload).
- Orchestration dependencies: `rank_combinations`, `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `combination_matrix_groups_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `combination_matrix_groups_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=combination_matrix_groups

```sql
CREATE TEMP TABLE combination_matrix_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'combination_matrix_groups'
  AND target_db = current_database();
```

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=vessel, target_table=categories

```sql
CREATE TEMP TABLE IF NOT EXISTS vessel_categories_id_mapping AS
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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rank_combination_matrix_mappings'::VARCHAR(100), legacy_data.id::text, current_database()::... |
| 2 | derived | - | group_id | - | cmg_map.new_id as group_id | cmg_map.new_id |
| 3 | rank_combination_id | - | rank_combination_id | - | legacy_data.rank_combination_id as rank_combination_id | legacy_data.rank_combination_id |
| 4 | experience_in_operator | - | experience_in_operator | - | legacy_data.experience_in_operator::numeric as experience_in_operator | legacy_data.experience_in_operator::numeric |
| 5 | experience_in_rank | - | experience_in_rank | - | legacy_data.experience_in_rank::numeric as experience_in_rank | legacy_data.experience_in_rank::numeric |
| 6 | experience_in_vessel_type | - | experience_in_vessel_type | - | legacy_data.experience_in_vessel_type::numeric as experience_in_vessel_type | legacy_data.experience_in_vessel_type::numeric |
| 7 | experience_in_vessel_type | - | experience_in_combination_group | - | legacy_data.experience_in_vessel_type::numeric as experience_in_combination_group | legacy_data.experience_in_vessel_type::numeric |
| 8 | experience_in_all_vessel_type | - | experience_in_all_vessel_type | - | COALESCE( ( SELECT jsonb_object_agg( vc_map.new_id::text, (elem->>'experiance')::numeric ) FROM jsonb_array_elements(legacy_data.experience_in_all_vessel_type) AS elem INNER JOI... | COALESCE( ( SELECT jsonb_object_agg( vc_map.new_id::text, (elem->>'experiance')::numeric ) FROM jsonb_array_elements(legacy_data.experience_in_all_vessel_type) AS elem INNER JOI... |
| 9 | experience_in_doc | - | experience_in_doc | - | legacy_data.experience_in_doc::numeric as experience_in_doc | legacy_data.experience_in_doc::numeric |
| 10 | appraisal_considered | - | appraisal_considered | - | COALESCE(legacy_data.appraisal_considered, false) as appraisal_considered | COALESCE(legacy_data.appraisal_considered, false) |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | created_by, updated_by, deleted_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Combination Matrix Groups ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='combination_matrix_groups'`

```sql
CREATE TEMP TABLE combination_matrix_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'combination_matrix_groups'
  AND target_db = current_database();
```

### 2. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='categories'`

```sql
CREATE TEMP TABLE IF NOT EXISTS vessel_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_schema = 'vessel'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/combination_matrix_migration.sql`

## Validation

- Run `05-validation/master/combination_matrix_validation.sql` if available
- Run `06-rollback/master/combination_matrix_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
