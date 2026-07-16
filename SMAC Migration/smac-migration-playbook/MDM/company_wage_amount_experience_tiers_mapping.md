# Table Mapping: wage_amounts → company_wage_amount_experience_tiers

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: wage_amounts
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_amount_experience_tiers
- **Source Script**: `04-migration-scripts/master/company_wage_amount_experience_tiers_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.wage_amounts`
- **New Path**: `smac_master_migration.crewing.company_wage_amount_experience_tiers`

## Business Key

- **Composite Key**: (`company_wage_chart_experience_tier_id`, `company_wage_scale_id`)
- **Source (orchestration)**: Company Wage Amount Experience Tiers (`wage_amounts` → `company_wage_amount_experience_tiers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_amount_experience_tiers from synergy_crewwage.public.wage_amounts. Maps wage_chart_id → company_wage_chart_id via company_wage_charts lookup. Maps wage_scale_id → company_wage_scale_id via company_wage_scales lookup. Maps min_experience/max_experience → company_wage_chart_experience_tier_id via company_wage_chart_experience_tiers lookup. Uses migration.resolve_target_id() for idempotent UUID generation since source has no identifier/uuid columns. Requires company_wage_chart_experience_tiers and company_wage_scales to be migrated first.

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_amount_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `company_wage_chart_experience_tiers`, `company_wage_scales`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_scale_to_chart_mapping` | FK lookup | `legacy_wage_scale_id`, `legacy_wage_chart_id` | - | `synergy_crewwage` |
| `company_wage_chart_experience_tiers_id_mapping` | FK lookup | `legacy_wage_amount_id`, `legacy_wage_scale_id`, `wa.min_experience`, `wa.max_experience`, `company_wage_chart_experience_tier_id` | `migration.table_mappings` (see SQL) | `synergy_crewwage` |

### `company_wage_scales_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_scales

```sql
CREATE TEMP TABLE company_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scales'
  AND target_db = current_database();
```

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

### `company_wage_chart_experience_tiers_id_mapping`

- **Output columns**: legacy_wage_amount_id, legacy_wage_scale_id, wa.min_experience, wa.max_experience, company_wage_chart_experience_tier_id
- **migration.table_mappings**: target_table=company_wage_charts
- **dblink connection**: `synergy_crewwage`

```sql
CREATE TEMP TABLE company_wage_chart_experience_tiers_id_mapping AS
SELECT DISTINCT ON (wa.id::text)
    wa.id::text as legacy_wage_amount_id,
    wa.wage_scale_id::text as legacy_wage_scale_id,
    wa.min_experience,
    wa.max_experience,
    cwcet.id as company_wage_chart_experience_tier_id
FROM dblink('synergy_crewwage',
    'SELECT id, wage_scale_id, min_experience, max_experience FROM public.wage_amounts WHERE min_experience IS NOT NULL'
) AS wa(id bigint, wage_scale_id bigint, min_experience integer, max_experience integer)
JOIN wage_scale_to_chart_mapping wstc ON wstc.legacy_wage_scale_id = wa.wage_scale_id::text
JOIN migration.table_mappings cwc_mapping
    ON cwc_mapping.source_id = wstc.legacy_wage_chart_id
    AND cwc_mapping.target_table = 'company_wage_charts'
    AND cwc_mapping.target_db = current_database()
JOIN crewing.company_wage_chart_experience_tiers cwcet
    ON cwcet.company_wage_chart_id = cwc_mapping.target_id
    AND cwcet.range_start = wa.min_experience::numeric
    AND (cwcet.range_end = wa.max_experience::numeric OR (cwcet.range_end IS NULL AND wa.max_experience IS NULL))
ORDER BY wa.id::text, cwcet.id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'wage_amounts'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | derived | - | company_wage_chart_experience_tier_id | - | cwcet_mapping.company_wage_chart_experience_tier_id | cwcet_mapping.company_wage_chart_experience_tier_id |
| 3 | derived | - | company_wage_scale_id | - | cws_mapping.new_id as company_wage_scale_id | cws_mapping.new_id |
| 4 | basic_amount | - | pay | - | legacy_data.basic_amount as pay | legacy_data.basic_amount |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | level | - | 0 as level | 0 |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 11 | isdeleted, updated_at, created_at | - | deleted_at | - | CASE WHEN legacy_data.isdeleted = true THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END as deleted_at | CASE WHEN legacy_data.isdeleted = true THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::te... |
| 14 | - | - | tags | - | NULL | NULL::text[] |
| 15 | isdeleted | - | status | - | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.company_wage_chart_experience_tiers`
- `crewing.company_wage_scales`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Scales ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_scales'`

```sql
CREATE TEMP TABLE company_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scales'
  AND target_db = current_database();
```

### 2. Wage Scale To Chart ID Mapping
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

### 3. Company Wage Chart Experience Tiers ID Mapping
**Output columns**: `legacy_wage_amount_id, legacy_wage_scale_id, wa.min_experience, wa.max_experience, company_wage_chart_experience_tier_id`
**migration.table_mappings**: `target_table='company_wage_charts'`
**dblink**: `synergy_crewwage`

```sql
CREATE TEMP TABLE company_wage_chart_experience_tiers_id_mapping AS
SELECT DISTINCT ON (wa.id::text)
    wa.id::text as legacy_wage_amount_id,
    wa.wage_scale_id::text as legacy_wage_scale_id,
    wa.min_experience,
    wa.max_experience,
    cwcet.id as company_wage_chart_experience_tier_id
FROM dblink('synergy_crewwage',
    'SELECT id, wage_scale_id, min_experience, max_experience FROM public.wage_amounts WHERE min_experience IS NOT NULL'
) AS wa(id bigint, wage_scale_id bigint, min_experience integer, max_experience integer)
JOIN wage_scale_to_chart_mapping wstc ON wstc.legacy_wage_scale_id = wa.wage_scale_id::text
JOIN migration.table_mappings cwc_mapping
    ON cwc_mapping.source_id = wstc.legacy_wage_chart_id
    AND cwc_mapping.target_table = 'company_wage_charts'
    AND cwc_mapping.target_db = current_database()
JOIN crewing.company_wage_chart_experience_tiers cwcet
    ON cwcet.company_wage_chart_id = cwc_mapping.target_id
    AND cwcet.range_start = wa.min_experience::numeric
    AND (cwcet.range_end = wa.max_experience::numeric OR (cwcet.range_end IS NULL AND wa.max_experience IS NULL))
ORDER BY wa.id::text, cwcet.id;
```

Full migration context: `04-migration-scripts/master/company_wage_amount_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/company_wage_amount_experience_tiers_validation.sql` if available
- Run `06-rollback/master/company_wage_amount_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
