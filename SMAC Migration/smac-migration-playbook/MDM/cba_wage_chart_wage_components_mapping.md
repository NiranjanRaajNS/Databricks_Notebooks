# Table Mapping: cba_wage_chart_wage_components → cba_wage_chart_wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_chart_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_chart_wage_components
- **Source Script**: `04-migration-scripts/master/cba_wage_chart_wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_chart_wage_components`
- **New Path**: `smac_master_migration.crewing.cba_wage_chart_wage_components`

## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `wage_component_id`)
- **Source (orchestration)**: CBA Wage Chart Wage Components (`cba_wage_chart_wage_components` → `cba_wage_chart_wage_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates cba_wage_chart_wage_components from synergy_master.wages schema. Depends on cba_wage_charts and wage_components. Preserves identifier/uuid when available.

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_chart_wage_components` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`, `wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_charts_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | Check if any mappings already exist for | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cba_wage_charts_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cba_wage_charts

```sql
CREATE TEMP TABLE cba_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_charts'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Purpose**: Check if any mappings already exist for
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_chart_wage_components'::VARCHAR(100), legacy_data.id::text, current_database()::tex... |
| 2 | derived | - | cba_wage_chart_id | - | COALESCE(cwc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as cba_wage_chart_id | COALESCE(cwc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | basic_wage_component_id | - | COALESCE(wc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as basic_wage_component_id | COALESCE(wc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 9 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_charts`
- `crewing.wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Charts ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cba_wage_charts'`

```sql
CREATE TEMP TABLE cba_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_charts'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Purpose**: Check if any mappings already exist for
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_wage_chart_wage_components_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_chart_wage_components_validation.sql` if available
- Run `06-rollback/master/cba_wage_chart_wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
