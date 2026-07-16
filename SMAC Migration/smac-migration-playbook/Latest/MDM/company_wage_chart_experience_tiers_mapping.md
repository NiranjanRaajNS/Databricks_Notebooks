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

- Deduped from `wage_amounts` on (chart, min_experience, max_experience)
- Composite source_id: `chart_id_min_max`
- `experience_type` hardcoded `'Rank'`
- Filter: `min_experience NOT NULL`; chart mapping exists

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
| 1 | `wage_chart_id, min_experience, max_experience` | bigint, integer, integer | `id` | uuid | `migration.resolve_target_id()` — composite source_id; `p_target_id = NULL` | Idempotent UUID |
| 2 | `wage_chart_id` | bigint | `company_wage_chart_id` | uuid | Map via `company_wage_charts_id_mapping` | FK lookup |
| 3 | `min_experience` | integer | `range_start` | integer | Direct copy |  |
| 4 | `max_experience` | integer | `range_end` | integer | Direct copy |  |
| 5 | `—` | — | `experience_type` | text | Hardcoded `'Rank'` | SMAC default |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 12 | `isdeleted` | boolean | `status` | integer | `isdeleted` → Deleted (3); else Active (0) |  |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 15 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Uses status from isdeleted |
| 16 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 17 | `created_by_id, updated_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 18 | `—` | — | `tags` | text[] | `NULL` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_charts`
- `company_wage_scales`
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
