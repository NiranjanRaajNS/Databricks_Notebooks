# Table Mapping: range_based_components → range_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: range_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: range_based_components
- **Source Script**: `04-migration-scripts/master/range_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.range_based_components`
- **New Path**: `smac_master_migration.crewing.range_based_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Range Based Components (`range_based_components` → `range_based_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates range_based_components preserving identifier UUID as id

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.range_based_components` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `derived_wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=derived_wage_components

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'range_based_components'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCH... |
| 2 | pay | - | pay | - | legacy_data.pay as pay | legacy_data.pay |
| 3 | salary_range_start | - | salary_range_start | - | legacy_data.salary_range_start as salary_range_start | legacy_data.salary_range_start |
| 4 | salary_range_end | - | salary_range_end | - | legacy_data.salary_range_end as salary_range_end | legacy_data.salary_range_end |
| 5 | isactive | - | isactive | - | COALESCE(legacy_data.isactive, true) as isactive | COALESCE(legacy_data.isactive, true) |
| 6 | derived_from_component_type | - | derived_from_component_type | - | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.derived_from_component_type, ''))) = 'BASIC' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.derived_from_component_type, ''))) = 'DERIVED'... | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.derived_from_component_type, ''))) = 'BASIC' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.derived_from_component_type, ''))) = 'DERIVED'... |
| 7 | - | - | derived_component_id | - | See source script | See source script |
| 8 | - | - | derived_from_component_id | - | See source script | See source script |
| 9 | - | - | tenant_id | - | See source script | See source script |
| 10 | - | - | version | - | See source script | See source script |
| 11 | - | - | defined_by | - | See source script | See source script |
| 12 | - | - | workflow_status | - | See source script | See source script |
| 13 | - | - | status | - | See source script | See source script |
| 14 | - | - | created_at | - | See source script | See source script |
| 15 | - | - | updated_at | - | See source script | See source script |
| 16 | - | - | audit_info | - | See source script | See source script |
| 17 | - | - | level | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Derived Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='derived_wage_components'`

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/range_based_components_migration.sql`

## Validation

- Run `05-validation/master/range_based_components_validation.sql` if available
- Run `06-rollback/master/range_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
