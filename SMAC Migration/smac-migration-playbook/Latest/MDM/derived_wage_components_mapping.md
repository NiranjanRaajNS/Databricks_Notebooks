# Table Mapping: derived_wage_components → derived_wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: derived_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: derived_wage_components
- **Source Script**: `04-migration-scripts/master/derived_wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.derived_wage_components`
- **New Path**: `smac_master_migration.crewing.derived_wage_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Derived Wage Components (`derived_wage_components` → `derived_wage_components`)

## Migration Notes

- Source: `synergy_master.wages.derived_wage_components` (schema `wages`, not `public`)
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `base_component_id` mapped from `component_id` via `wage_components_id_mapping`
- `type` mapped from `calculation_type`: Formula->1, Percentage->2, Range->3
- `status` derived from `deleted_at` — Case 1
- Requires `wage_components` migrated first


## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.derived_wage_components` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wage_components_id_mapping` | Cle | `legacy_component_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `wage_components_id_mapping`

- **Purpose**: Cle
- **Output columns**: legacy_component_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::uuid AS legacy_component_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved; Pattern 4 |
| 2 | `component_id` | uuid | `base_component_id` | uuid | Map via `wage_components_id_mapping` | FK: `wage_components` |
| 3 | `calculation_type` | character varying | `type` | integer | FORMULA->1, PERCENTAGE->2, RANGE->3; else 0 | Enum mapping |
| 4 | `identifier`, `description` | text | `code` | text | `COALESCE(NULLIF(TRIM(identifier), ''), UPPER(REGEXP_REPLACE(TRIM(description), ...)))` | |
| 5 | `component_id` (via join) | — | `name` | text | `COALESCE(TRIM(wage_components.name), 'Derived Component')` | From joined wage component |
| 6 | `description` | text | `description` | text | Direct copy | |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 8 | — | — | `version` | integer | Hardcoded `1` | |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 11 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` -> Deleted (3); else Active (0) | Case 1 |
| 12 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 13 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 14 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | |
| 15 | `calculation_type` | character varying | `tags` | text[] | Single-element array from `calculation_type` when non-empty | |
| 16 | `created_by`, `updated_by` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; creator/updater in `notes` | No `legacy_id` |
| 17 | — | — | `level` | numeric | Hardcoded `0` | |

**SAC columns not migrated:** `deleted_by` — not mapped to SMAC audit fields.


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wage Components ID Mapping
**Purpose**: Cle
**Output columns**: `legacy_component_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::uuid AS legacy_component_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/derived_wage_components_migration.sql`

## Validation

- Run `05-validation/master/derived_wage_components_validation.sql` if available
- Run `06-rollback/master/derived_wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
