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

- Composite source_id: `id || '_' || country`
- `nationality_id` from country code via `nationalities` mapping
- Filter: `type=0`, name and country NOT NULL; chart + nationality mappings required

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
| 1 | `id, country` | bigint, text | `id` | uuid | `migration.resolve_target_id()` — composite `id || '_' || country`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `id` | bigint | `company_wage_chart_id` | uuid | Map via `company_wage_charts_id_mapping` | FK lookup |
| 3 | `country` | text | `nationality_id` | uuid | Match country code to `nationalities.code` | FK lookup |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 5 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 6 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 10 | `isdeleted, deleted_at` | boolean, timestamp without time zone | `status` | integer | `isdeleted` or `deleted_at` → Deleted (3); else Active (0) |  |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 14 | `—` | — | `archived_at` | timestamp without time zone | `NULL` |  |
| 15 | `—` | — | `tags` | text[] | `NULL` |  |
| 16 | `created_by_id, updated_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_charts`
- `nationalities`

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
