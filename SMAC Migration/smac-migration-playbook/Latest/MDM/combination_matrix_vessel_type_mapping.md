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

- SAC `id` (uuid) preserved
- `vessel_type_id` mapped from integer via `categories_id_mapping`
- Filter: `combination_matrix_id` and vessel_type mapping NOT NULL

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `combination_matrix_id` | uuid | `combination_matrix_id` | uuid | Direct copy (uuid preserved) |  |
| 3 | `vessel_type_id` | integer | `vessel_type_id` | uuid | Map via `categories_id_mapping` | FK lookup int→UUID |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 5 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 6 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 7 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 8 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 9 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 10 | `created_by, updated_by, deleted_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`
- `combination_matrix`

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
