# Table Mapping: formula_based_components → formula_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: formula_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: formula_based_components
- **Source Script**: `04-migration-scripts/master/formula_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.formula_based_components`
- **New Path**: `smac_master_migration.crewing.formula_based_components`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Formula Based Components (`formula_based_components` → `formula_based_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- derived_wage_components has UUID id column, so source_id is stored as UUID text
- Migrates formula_based_components table. Source table does not have identifier/uuid columns - generates new UUID for all records. Columns: derived_component_id (uuid, mapped via derived_wage_components lookup), formula (text), variables (jsonb), version_number → version (integer), isactive (boolean). Maps isactive to status (false = Active (0), false = Deleted (3)). Source schema is wages (not public). Depends on derived_wage_components.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.formula_based_components` before insert (full table reload).
- Orchestration dependencies: `derived_wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'formula_based_components'::VARCHAR(100), legacy_data.id::text, current_database()::text::VAR... |
| 2 | derived | - | derived_component_id | - | COALESCE(derived_wage_components_lookup.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as derived_component_id | COALESCE(derived_wage_components_lookup.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | formula | - | formula | - | legacy_data.formula as formula | legacy_data.formula |
| 4 | variables | - | variables | - | legacy_data.variables as variables | legacy_data.variables |
| 5 | version_number | - | version | - | legacy_data.version_number as version | legacy_data.version_number |
| 6 | isactive | - | isactive | - | legacy_data.isactive as isactive | legacy_data.isactive |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | level | - | 0 as level | 0 |
| 10 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() as created_at | NOW() as created_at |
| 12 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 15 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 16 | isactive | - | status | - | CASE WHEN legacy_data.isactive = true THEN 0 ELSE 3 END as status | CASE WHEN legacy_data.isactive = true THEN 0 ELSE 3 END |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.derived_wage_components`

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

Full migration context: `04-migration-scripts/master/formula_based_components_migration.sql`

## Validation

- Run `05-validation/master/formula_based_components_validation.sql` if available
- Run `06-rollback/master/formula_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
