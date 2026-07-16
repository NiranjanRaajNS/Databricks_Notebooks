# Table Mapping: company_wage_scales → company_wage_scales

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: company_wage_scales
- **Source Script**: `04-migration-scripts/master/company_wage_scales_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Scales (`wage_scales` → `company_wage_scales`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_scales from synergy_crewwage.public.wage_scales. Preserves identifier/uuid when available.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_scales` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_charts_id_mapping` | Check if any mappings already exist for the given sourc | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `company_wage_charts_id_mapping`

- **Purpose**: Check if any mappings already exist for the given sourc
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_charts

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_charts'
  AND target_db = current_database();
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'wage_scales'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | derived | - | company_wage_chart_id | - | COALESCE(cwc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as company_wage_chart_id | COALESCE(cwc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | rank_id | - | COALESCE(rank_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as rank_id | COALESCE(rank_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | isdeleted | - | status | - | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 9 | derived | - | no_of_other_allowance | - | 0 as no_of_other_allowance | 0 |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 13 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Charts ID Mapping
**Purpose**: Check if any mappings already exist for the given sourc
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_charts'`

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_charts'
  AND target_db = current_database();
```

### 2. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_scales_migration.sql`

## Validation

- Run `05-validation/master/company_wage_scales_validation.sql` if available
- Run `06-rollback/master/company_wage_scales_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
