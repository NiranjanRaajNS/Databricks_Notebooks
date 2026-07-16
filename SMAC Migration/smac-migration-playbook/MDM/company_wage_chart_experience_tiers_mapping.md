# Table Mapping: wage_amounts → company_wage_chart_experience_tiers

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_amounts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_chart_experience_tiers
- **Source Script**: `04-migration-scripts/master/company_wage_chart_experience_tiers_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_amounts`
- **New Path**: `smac_master_migration.crewing.company_wage_chart_experience_tiers`

## Business Key

- **Composite Key**: (`company_wage_chart_id`, `range_start`, `range_end`)
- **Source (orchestration)**: Company Wage Chart Experience Tiers (`wage_amounts` → `company_wage_chart_experience_tiers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_chart_experience_tiers from synergy_crewwage.public.wage_amounts. Extracts distinct min_experience/max_experience combinations per wage chart. Maps wage_scale_id → company_wage_chart_id via company_wage_scales lookup. Maps min_experience → range_start, max_experience → range_end. Uses migration.resolve_target_id() for idempotent UUID generation since source has no identifier/uuid columns. Requires company_wage_charts and company_wage_scales to be migrated first.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_chart_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `company_wage_charts`, `company_wage_scales`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wage_scale_to_chart_mapping` | FK lookup | `legacy_wage_scale_id`, `legacy_wage_chart_id` | - | `synergy_crewwage` |
| `company_wage_charts_id_mapping` | FK lookup | `wstc.legacy_wage_scale_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `wage_scale_to_chart_mapping`

- **Output columns**: legacy_wage_scale_id, legacy_wage_chart_id
- **dblink connection**: `synergy_crewwage`

```sql
CREATE TEMP TABLE wage_scale_to_chart_mapping AS
SELECT
    ws.id::text as legacy_wage_scale_id,
    ws.wage_chart_id::text as legacy_wage_chart_id
FROM dblink('synergy_crewwage',
    'SELECT id, wage_chart_id FROM public.wage_scales'
) AS ws(id bigint, wage_chart_id bigint);
```

### `company_wage_charts_id_mapping`

- **Output columns**: wstc.legacy_wage_scale_id, new_id
- **migration.table_mappings**: target_table=company_wage_charts

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    wstc.legacy_wage_scale_id,
    cwc_mapping.target_id as new_id
FROM wage_scale_to_chart_mapping wstc
JOIN migration.table_mappings cwc_mapping
    ON cwc_mapping.source_id = wstc.legacy_wage_chart_id
    AND cwc_mapping.target_table = 'company_wage_charts'
    AND cwc_mapping.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | min_experience, max_experience | - | id | - | migration.resolve_target_id() | DISTINCT ON (cwc_mapping.new_id, legacy_data.min_experience::numeric(10,2), legacy_data.max_experience::numeric(10,2)) migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(1... |
| 2 | derived | - | company_wage_chart_id | - | cwc_mapping.new_id as company_wage_chart_id | cwc_mapping.new_id |
| 3 | min_experience | - | range_start | - | legacy_data.min_experience::numeric(10,2) as range_start | legacy_data.min_experience::numeric(10,2) |
| 4 | max_experience | - | range_end | - | legacy_data.max_experience::numeric(10,2) as range_end | legacy_data.max_experience::numeric(10,2) |
| 5 | derived | - | experience_type | - | 'Rank'::text as experience_type | 'Rank'::text |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | level | - | 0 as level | 0 |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | isdeleted | - | status | - | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 15 | isdeleted, updated_at, created_at | - | deleted_at | - | CASE WHEN legacy_data.isdeleted = true THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END as deleted_at | CASE WHEN legacy_data.isdeleted = true THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::te... |
| 18 | derived | - | tags | - | ARRAY[]::text[] as tags | ARRAY[]::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.company_wage_charts`
- `crewing.company_wage_scales`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wage Scale To Chart ID Mapping
**Output columns**: `legacy_wage_scale_id, legacy_wage_chart_id`
**dblink**: `synergy_crewwage`

```sql
CREATE TEMP TABLE wage_scale_to_chart_mapping AS
SELECT
    ws.id::text as legacy_wage_scale_id,
    ws.wage_chart_id::text as legacy_wage_chart_id
FROM dblink('synergy_crewwage',
    'SELECT id, wage_chart_id FROM public.wage_scales'
) AS ws(id bigint, wage_chart_id bigint);
```

### 2. Company Wage Charts ID Mapping
**Output columns**: `wstc.legacy_wage_scale_id, new_id`
**migration.table_mappings**: `target_table='company_wage_charts'`

```sql
CREATE TEMP TABLE company_wage_charts_id_mapping AS
SELECT
    wstc.legacy_wage_scale_id,
    cwc_mapping.target_id as new_id
FROM wage_scale_to_chart_mapping wstc
JOIN migration.table_mappings cwc_mapping
    ON cwc_mapping.source_id = wstc.legacy_wage_chart_id
    AND cwc_mapping.target_table = 'company_wage_charts'
    AND cwc_mapping.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_chart_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/company_wage_chart_experience_tiers_validation.sql` if available
- Run `06-rollback/master/company_wage_chart_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
