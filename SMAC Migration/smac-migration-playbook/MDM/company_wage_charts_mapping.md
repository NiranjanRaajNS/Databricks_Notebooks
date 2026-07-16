# Table Mapping: wage_charts → company_wage_charts

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_charts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_charts
- **Source Script**: `04-migration-scripts/master/company_wage_charts_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_charts`
- **New Path**: `smac_master_migration.crewing.company_wage_charts`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Charts (`wage_charts` → `company_wage_charts`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_charts from synergy_crewwage.public.wage_charts. Generates new UUIDs for id (identifier/uuid not available in source). Code generated from name. Status defaults to Active (0). company_wage_group_id mapped from vessel_group_id via migration.table_mappings. is_all_nationalities and currency_id mapped from cba_code via crewing.cbas table.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Only migrate rows where type = 0
- Script performs `TRUNCATE TABLE crewing.company_wage_charts` before insert (full table reload).
- Orchestration dependencies: `company_wage_groups`, `cbas`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_groups_id_mapping` | Check if target table has exist | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `currencies_id_mapping` | Check if any mappings already | `legacy_id`, `new_id`, `currency_code` | `migration.table_mappings` (see SQL) | - |

### `company_wage_groups_id_mapping`

- **Purpose**: Check if target table has exist
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_groups

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### `currencies_id_mapping`

- **Purpose**: Check if any mappings already
- **Output columns**: legacy_id, new_id, currency_code
- **migration.table_mappings**: target_table=currencies

```sql
CREATE TEMP TABLE currencies_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.code as currency_code
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'wage_charts'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | name | - | code | - | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) as code | UPPER(REPLACE(TRIM(legacy_data.name), ' ', '_')) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | company_wage_group_id | - | COALESCE(cwg_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as company_wage_group_id | COALESCE(cwg_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | effective_date | - | effective_date | - | legacy_data.effective_date as effective_date | legacy_data.effective_date |
| 7 | is_all_nationalities | - | is_all_nationalities | - | COALESCE(cbas.is_all_nationalities, false) as is_all_nationalities | COALESCE(cbas.is_all_nationalities, false) |
| 8 | derived | - | currency_id | - | COALESCE( (SELECT id FROM public.currencies WHERE UPPER(TRIM(code)) = 'USD' LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) as currency_id | COALESCE( (SELECT id FROM public.currencies WHERE UPPER(TRIM(code)) = 'USD' LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at, isdeleted | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL OR legacy_data.isdeleted = true THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL OR legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | created_by_id, updated_by_id, created_by_name, updated_by_name, id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |
| 17 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Groups ID Mapping
**Purpose**: Check if target table has exist
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_groups'`

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### 2. Currencies ID Mapping
**Purpose**: Check if any mappings already
**Output columns**: `legacy_id, new_id, currency_code`
**migration.table_mappings**: `target_table='currencies'`

```sql
CREATE TEMP TABLE currencies_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.code as currency_code
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_charts_migration.sql`

## Validation

- Run `05-validation/master/company_wage_charts_validation.sql` if available
- Run `06-rollback/master/company_wage_charts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
