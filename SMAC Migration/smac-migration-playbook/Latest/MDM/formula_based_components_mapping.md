# Table Mapping: formula_based_components → formula_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: formula_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: formula_based_components
- **Source Script**: `04-migration-scripts/master/formula_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.formula_based_components`
- **New Path**: `smac_master_migration.crewing.formula_based_components`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Formula Based Components (`formula_based_components` → `formula_based_components`)

## Migration Notes

- Source: `synergy_master.wages.formula_based_components` → `crewing.formula_based_components`
- SAC `id` (uuid) preserved via `resolve_target_id()` with `p_target_id = id`
- Depends on `derived_wage_components` migrated first
- `derived_wage_components_id_mapping` FK lookup from `migration.table_mappings`
- TRUNCATE target; no duplicate UUID check in script
- `status` from `isactive` boolean (true→Active 0, false→Deleted 3)
- `created_at`/`updated_at` set to `NOW()` — not in SAC source

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.formula_based_components` before insert (full table reload).
- Orchestration dependencies: `derived_wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `derived_wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=derived_wage_components

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid |
| 2 | `derived_component_id` | uuid | `derived_component_id` | uuid | Map via `derived_wage_components_id_mapping`; fallback zero-UUID | FK lookup |
| 3 | `formula` | text | `formula` | text | Direct copy |  |
| 4 | `variables` | jsonb | `variables` | jsonb | Direct copy |  |
| 5 | `version_number` | integer | `version` | integer | Direct copy |  |
| 6 | `isactive` | boolean | `isactive` | boolean | Direct copy |  |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `created_at` | timestamptz | `NOW()` | Not in SAC |
| 11 | `—` | — | `updated_at` | timestamptz | `NOW()` (script aliases both timestamp columns as `created_at` in INSERT) | Not in SAC |
| 12 | `—` | — | `deleted_at` | timestamptz | `NULL` | Not in SAC |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 14 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 15 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 16 | `isactive` | boolean | `status` | integer | `isactive = true` → Active (0); `false` → Deleted (3) |  |

**SAC columns not migrated:** None — all selected columns used.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.derived_wage_components`
- `derived_wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Derived Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='derived_wage_components'`

```sql
CREATE TEMP TABLE derived_wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'derived_wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/formula_based_components_migration.sql`

## Validation

- Run `05-validation/master/formula_based_components_validation.sql` if available
- Run `06-rollback/master/formula_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
