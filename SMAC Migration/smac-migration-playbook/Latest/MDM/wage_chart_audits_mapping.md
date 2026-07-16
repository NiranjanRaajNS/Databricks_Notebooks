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

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Source: `synergy_master.wages.cba_wage_chart_audit` → `crewing.wage_chart_audits`
- `entity` hardcoded `'cba_wage_chart'`; `entity_id` from `cba_wage_chart_id` FK mapping
- `cba_wage_charts_id_mapping` from `migration.table_mappings`
- `changed_on` used for both `created_at` and `updated_at`
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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `—` | — | `entity` | text | Hardcoded `'cba_wage_chart'` | Constant entity type |
| 3 | `cba_wage_chart_id` | uuid | `entity_id` | uuid | Map via `cba_wage_charts_id_mapping` or placeholder UUID | FK lookup |
| 4 | `action` | text | `action` | text | `LEFT(COALESCE(action, ''), 20)` | Truncated to 20 chars |
| 5 | `description` | text | `description` | text | `COALESCE(description, '')` | Direct copy |
| 6 | `—` | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 8 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 9 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 12 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No deleted_at in SAC source |
| 13 | `changed_on` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(changed_on, NOW())` | Uses changed_on as created_at |
| 14 | `changed_on` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(changed_on, NOW())` | Same timestamp for create/update |
| 15 | `—` | — | `deleted_at` | timestamptz | Hardcoded NULL | Not in SAC source |
| 16 | `—` | — | `archived_at` | timestamptz | Hardcoded NULL | Not in SAC source |
| 17 | `changed_by` | text | `audit_info` | jsonb | `migration.build_audit_info(changed_by)` | Audit user from changed_by |
| 18 | `—` | — | `tags` | text[] | Hardcoded NULL | Not populated from SAC |

**SAC columns not migrated:** None from dblink SELECT.

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
