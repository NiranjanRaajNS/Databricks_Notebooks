# Table Mapping: cba_wage_chart → cba_wage_charts

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_chart
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_charts
- **Source Script**: `04-migration-scripts/master/cba_wage_charts_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_chart`
- **New Path**: `smac_master_migration.crewing.cba_wage_charts`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cba Wage Chart (`cba_wage_chart` → `cba_wage_charts`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Source schema is wages (not public), source table name is cba_wage_chart (singular)

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_charts` before insert (full table reload).
- Orchestration dependencies: `cbas`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | Check if | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cbas_id_mapping`

- **Purpose**: Check if
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_chart'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | name | - | code | - | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) as code | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | derived | - | cba_id | - | cba_mapping.new_id as cba_id | cba_mapping.new_id |
| 5 | include_superior_certificate | - | include_superior_certificate | - | COALESCE(legacy_data.include_superior_certificate, false) as include_superior_certificate | COALESCE(legacy_data.include_superior_certificate, false) |
| 6 | effective_date | - | effective_date | - | legacy_data.effective_date as effective_date | legacy_data.effective_date |
| 7 | derived | - | level | - | 0 as level | 0 |
| 8 | derived | - | description | - | NULL as description | NULL |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | derived | - | status | - | 0 as status | 0 |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cbas`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cbas ID Mapping
**Purpose**: Check if
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cbas'`

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/master/cba_wage_charts_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_charts_validation.sql` if available
- Run `06-rollback/master/cba_wage_charts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
