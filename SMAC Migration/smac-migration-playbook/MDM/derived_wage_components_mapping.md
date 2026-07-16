# Table Mapping: derived_wage_components → derived_wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: derived_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: derived_wage_components
- **Source Script**: `04-migration-scripts/master/derived_wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.derived_wage_components`
- **New Path**: `smac_master_migration.crewing.derived_wage_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Derived Wage Components (`derived_wage_components` → `derived_wage_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates derived_wage_components preserving identifier UUID as id if available. Source schema is wages, not public

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.derived_wage_components` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wage_components_id_mapping` | Cle | `legacy_component_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `wage_components_id_mapping`

- **Purpose**: Cle
- **Output columns**: legacy_component_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::uuid AS legacy_component_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'derived_wage_components'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | derived | - | base_component_id | - | component_mapping.new_id as base_component_id | component_mapping.new_id |
| 3 | calculation_type | - | type | - | CASE WHEN UPPER(TRIM(legacy_data.calculation_type)) = 'FORMULA' THEN 1 WHEN UPPER(TRIM(legacy_data.calculation_type)) = 'PERCENTAGE' THEN 2 WHEN UPPER(TRIM(legacy_data.calculati... | CASE WHEN UPPER(TRIM(legacy_data.calculation_type)) = 'FORMULA' THEN 1 WHEN UPPER(TRIM(legacy_data.calculation_type)) = 'PERCENTAGE' THEN 2 WHEN UPPER(TRIM(legacy_data.calculati... |
| 4 | identifier, description | - | code | - | COALESCE( NULLIF(TRIM(legacy_data.identifier), ''), UPPER(REGEXP_REPLACE(TRIM(legacy_data.description), '[^A-Za-z0-9]', '_', 'g')) ) as code | COALESCE( NULLIF(TRIM(legacy_data.identifier), ''), UPPER(REGEXP_REPLACE(TRIM(legacy_data.description), '[^A-Za-z0-9]', '_', 'g')) ) |
| 5 | derived | - | name | - | COALESCE(TRIM(wc.name), 'Derived Component') as name | COALESCE(TRIM(wc.name), 'Derived Component') |
| 6 | description | - | description | - | legacy_data.description as description | legacy_data.description |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | calculation_type | - | tags | - | CASE WHEN legacy_data.calculation_type IS NOT NULL AND TRIM(legacy_data.calculation_type) != '' THEN ARRAY[TRIM(legacy_data.calculation_type)] ELSE NULL END as tags | CASE WHEN legacy_data.calculation_type IS NOT NULL AND TRIM(legacy_data.calculation_type) != '' THEN ARRAY[TRIM(legacy_data.calculation_type)] ELSE NULL END |
| 16 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wage Components ID Mapping
**Purpose**: Cle
**Output columns**: `legacy_component_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::uuid AS legacy_component_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/derived_wage_components_migration.sql`

## Validation

- Run `05-validation/master/derived_wage_components_validation.sql` if available
- Run `06-rollback/master/derived_wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
