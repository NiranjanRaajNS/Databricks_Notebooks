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

- SAC `id` (uuid) preserved
- `vessel_id` mapped from integer via `vessels_id_mapping`
- Filter: `vessel_id NOT NULL` and mapping exists

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `vessel_id` | integer | `vessel_id` | uuid | Map via `vessels_id_mapping` | FK lookup int→UUID |
| 3 | `vessel_type_mapping_id` | uuid | `vessel_type_mapping_id` | uuid | Direct copy (uuid preserved) |  |
| 4 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 7 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 8 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 9 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 10 | `created_by, updated_by, deleted_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `combination_matrix`
- `vessels`

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
