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

- SAC `id` (uuid) preserved; `combination_matrix_id` → SMAC `group_id`
- `experience_in_combination_group` duplicates `experience_in_vessel_type`
- `experience_in_all_vessel_type` JSONB array remapped to object with vessel type UUIDs
- Filter: `rank_combination_id`, `combination_matrix_id`, and group mapping all NOT NULL

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `combination_matrix_id` | uuid | `group_id` | uuid | Map via `combination_matrix_groups_id_mapping` | FK: groups |
| 3 | `rank_combination_id` | uuid | `rank_combination_id` | uuid | Direct copy (uuid preserved) |  |
| 4 | `experience_in_operator` | numeric | `experience_in_operator` | numeric | Direct copy |  |
| 5 | `experience_in_rank` | numeric | `experience_in_rank` | numeric | Direct copy |  |
| 6 | `experience_in_vessel_type` | numeric | `experience_in_vessel_type` | numeric | Direct copy |  |
| 7 | `experience_in_vessel_type` | numeric | `experience_in_combination_group` | numeric | Duplicate of `experience_in_vessel_type` | SMAC-only semantic rename |
| 8 | `experience_in_all_vessel_type` | jsonb | `experience_in_all_vessel_type` | jsonb | JSONB array → object; map `vessel_type_id` int → UUID via categories mapping | Complex JSON transform |
| 9 | `experience_in_doc` | numeric | `experience_in_doc` | numeric | Direct copy |  |
| 10 | `appraisal_considered` | boolean | `appraisal_considered` | boolean | Direct copy |  |
| 11 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 12 | `is_active, deleted_at` | boolean, timestamp without time zone | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) |  |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 16 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 17 | `created_by, updated_by, deleted_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `rank_combinations`
- `ranks`

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
