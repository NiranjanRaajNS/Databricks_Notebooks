# Table Mapping: cba_wage_amounts → cba_wage_amounts

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_amounts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_amounts
- **Source Script**: `04-migration-scripts/master/cba_wage_amounts_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_amounts`
- **New Path**: `smac_master_migration.crewing.cba_wage_amounts`

## Business Key

- **Business Key**: `cba_wage_chart_id`
- **Source (orchestration)**: CBA Wage Amounts (`cba_wage_amounts` → `cba_wage_amounts`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates cba_wage_amounts from synergy_master.wages schema. Depends on cba_wage_charts. Preserves identifier/uuid when available.

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_amounts` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cba_wage_scales_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cba_wage_scales

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_amounts'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100... |
| 2 | derived | - | cba_wage_scale_id | - | cws_mapping.new_id as cba_wage_scale_id | cws_mapping.new_id |
| 3 | pay | - | pay | - | legacy_data.pay as pay | legacy_data.pay |
| 4 | applicable | - | applicable | - | COALESCE(legacy_data.applicable, true) as applicable | COALESCE(legacy_data.applicable, true) |
| 5 | derived | - | basic_wage_component_id | - | wc_mapping.new_id as basic_wage_component_id | wc_mapping.new_id |
| 6 | derived | - | derived_wage_component_id | - | dwc_mapping.new_id as derived_wage_component_id | dwc_mapping.new_id |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN legac... |
| 17 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_scales`
- `crewing.derived_wage_components`
- `crewing.wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Scales ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cba_wage_scales'`

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
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

### 3. Derived Wage Components ID Mapping
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

Full migration context: `04-migration-scripts/master/cba_wage_amounts_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_amounts_validation.sql` if available
- Run `06-rollback/master/cba_wage_amounts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
