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

- From `wage_amounts`; `pay` = `basic_amount` only
- FK joins via scale→chart→experience tier composite
- Filter: INNER JOIN requires scale + experience tier mappings
- OT fields not migrated

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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `wage_scale_id, min_experience, max_experience` | bigint, integer, integer | `company_wage_chart_experience_tier_id` | uuid | Join via scale→chart→experience tier composite | FK via multi-table join |
| 3 | `wage_scale_id` | bigint | `company_wage_scale_id` | uuid | Map via `company_wage_scales_id_mapping` | FK lookup |
| 4 | `basic_amount` | numeric | `pay` | numeric | Direct copy (`basic_amount` only) |  |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 6 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 7 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 11 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Uses status from isdeleted |
| 12 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 13 | `created_by_id, updated_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |
| 14 | `—` | — | `tags` | text[] | `NULL` |  |
| 15 | `isdeleted` | boolean | `status` | integer | `isdeleted` → Deleted (3); else Active (0) |  |
| 16 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 17 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |

**SAC columns not migrated:** `additional_amount`, `ot_rate`, `ot_hours`, `ot_amount`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_chart_experience_tiers`
- `company_wage_scales`
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
