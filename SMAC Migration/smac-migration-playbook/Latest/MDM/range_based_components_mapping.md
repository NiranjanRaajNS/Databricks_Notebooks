# Table Mapping: range_based_components → range_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: range_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: range_based_components
- **Source Script**: `04-migration-scripts/master/range_based_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.range_based_components`
- **New Path**: `smac_master_migration.crewing.range_based_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Range Based Components (`range_based_components` → `range_based_components`)

## Migration Notes

- Source: `synergy_master.wages.range_based_components` → `crewing.range_based_components`
- SAC `id` (uuid) preserved via `resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on `id`
- `derived_wage_components_id_mapping` + `wage_components_id_mapping` FK lookups
- `derived_from_component_type` text → integer: BASIC=1, DERIVED=2
- `status` from `isactive` boolean
- Timestamps set to `NOW()`

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.range_based_components` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

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

### `wage_components_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Pattern 4 |
| 2 | `pay` | numeric(10,2) | `pay` | numeric | Direct copy |  |
| 3 | `salary_range_start` | numeric(10,2) | `salary_range_start` | numeric | Direct copy |  |
| 4 | `salary_range_end` | numeric(10,2) | `salary_range_end` | numeric | Direct copy |  |
| 5 | `isactive` | boolean | `isactive` | boolean | `COALESCE(isactive, true)` |  |
| 6 | `derived_from_component_type` | varchar(150) | `derived_from_component_type` | integer | BASIC→1, DERIVED→2, else 1 |  |
| 7 | `derived_component_id` | uuid | `derived_component_id` | uuid | Map via `derived_wage_components_id_mapping` | FK lookup |
| 8 | `derived_from_component_id` | uuid | `derived_from_component_id` | uuid | Map via `wage_components_id_mapping` | FK lookup |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 13 | `isactive` | boolean | `status` | integer | `isactive = true` → Active (0); `false` → Deleted (3) |  |
| 14 | `—` | — | `created_at` | timestamp | `NOW()` |  |
| 15 | `—` | — | `updated_at` | timestamp | `NOW()` |  |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Pattern 4 |
| 17 | `—` | — | `level` | integer | Hardcoded `0` |  |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

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

### 2. Wage Components ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id as legacy_id_text,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/range_based_components_migration.sql`

## Validation

- Run `05-validation/master/range_based_components_validation.sql` if available
- Run `06-rollback/master/range_based_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
