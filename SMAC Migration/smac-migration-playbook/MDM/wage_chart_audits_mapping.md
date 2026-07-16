# Table Mapping: cba_wage_chart_audit → wage_chart_audits

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_chart_audit
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: wage_chart_audits
- **Source Script**: `04-migration-scripts/master/wage_chart_audits_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_chart_audit`
- **New Path**: `smac_master_migration.crewing.wage_chart_audits`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Wage Chart Audits (`cba_wage_chart_audit` → `wage_chart_audits`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- cba_wage_chart_id: crewing.cba_wage_charts (via table_mappings)
- Migrates wage_chart_audits preserving legacy UUID id

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.wage_chart_audits` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_charts_id_mapping` | Chec | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cba_wage_charts_id_mapping`

- **Purpose**: Chec
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_chart_audit'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | derived | - | entity | - | 'cba_wage_chart' AS entity | 'cba_wage_chart' |
| 3 | derived | - | entity_id | - | COALESCE(cba_chart_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) AS entity_id | COALESCE(cba_chart_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | action | - | action | - | LEFT(COALESCE(legacy_data.action, ''), 20) AS action | LEFT(COALESCE(legacy_data.action, ''), 20) |
| 5 | description | - | description | - | COALESCE(legacy_data.description, '') AS description | COALESCE(legacy_data.description, '') |
| 6 | derived | - | level | - | 0 AS level | 0 |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | version | - | 1 AS version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | derived | - | status | - | 0 AS status | 0 |
| 13 | changed_on | - | created_at | - | COALESCE(legacy_data.changed_on, NOW()) AS created_at | COALESCE(legacy_data.changed_on, NOW()) |
| 14 | changed_on | - | updated_at | - | COALESCE(legacy_data.changed_on, NOW()) AS updated_at | COALESCE(legacy_data.changed_on, NOW()) |
| 15 | - | - | deleted_at | - | NULL | NULL::timestamptz |
| 16 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 17 | changed_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.changed_by IS NOT NULL AND TRIM(legacy_data.changed_by) <> '' THEN TRIM(legacy_data.changed_by) ELSE NULL END::varchar, NULL::v... |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_charts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Charts ID Mapping
**Purpose**: Chec
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

Full migration context: `04-migration-scripts/master/wage_chart_audits_migration.sql`

## Validation

- Run `05-validation/master/wage_chart_audits_validation.sql` if available
- Run `06-rollback/master/wage_chart_audits_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
