# Table Mapping: wage_charts → company_wage_charts_applicability

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_charts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_charts_applicability
- **Source Script**: `04-migration-scripts/master/company_wage_charts_applicability_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_charts`
- **New Path**: `smac_master_migration.crewing.company_wage_charts_applicability`

## Business Key

- **Composite Key**: (`company_wage_chart_id`, `nationality_id`)
- **Source (orchestration)**: Company Wage Charts Applicability (`wage_charts` → `company_wage_charts_applicability`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_charts_applicability from synergy_crewwage.public.wage_charts (where type = 0). Creates one applicability record per wage_chart per matching nationality. company_wage_chart_id mapped from wage_charts.id via migration.table_mappings. nationality_id mapped by matching country field with synergy_master.public.nationalities.iso_code. Generates new UUIDs for id (identifier/uuid not available in source). Status mapped based on deleted_at and isdeleted fields.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Only migrate rows where type = 0
- Script performs `TRUNCATE TABLE crewing.company_wage_charts_applicability` before insert (full table reload).
- Orchestration dependencies: `company_wage_charts`, `nationalities`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_charts_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `nationalities_id_mapping` | Check if any mappings already exist for the given source and | `normalized_code`, `nationality_id` | - | - |

### `company_wage_charts_id_mapping`

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

### `nationalities_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and
- **Output columns**: normalized_code, nationality_id

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE n.code IS NOT NULL
  AND TRIM(n.code) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, country | - | id | - | migration.resolve_target_id() | DISTINCT ON (cwc_mapping.new_id, nat_mapping.nationality_id) migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'wage_charts'::VARCHAR(100), ... |
| 2 | derived | - | company_wage_chart_id | - | cwc_mapping.new_id AS company_wage_chart_id | cwc_mapping.new_id |
| 3 | derived | - | nationality_id | - | nat_mapping.nationality_id AS nationality_id | nat_mapping.nationality_id |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | - | - | parent_id | - | NULL | NULL::uuid |
| 6 | derived | - | level | - | 0 as level | 0 |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at, isdeleted | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL OR legacy_data.isdeleted = true THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL OR legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | - | - | tags | - | NULL | NULL::text[] |
| 16 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Charts ID Mapping
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

### 2. Nationalities ID Mapping
**Purpose**: Check if any mappings already exist for the given source and
**Output columns**: `normalized_code, nationality_id`

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE n.code IS NOT NULL
  AND TRIM(n.code) <> '';
```

Full migration context: `04-migration-scripts/master/company_wage_charts_applicability_migration.sql`

## Validation

- Run `05-validation/master/company_wage_charts_applicability_validation.sql` if available
- Run `06-rollback/master/company_wage_charts_applicability_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
