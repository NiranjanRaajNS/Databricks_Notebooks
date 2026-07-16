# Table Mapping: CargoFormulas → vessel_category_metric_definition

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: CargoFormulas
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_category_metric_definition
- **Source Script**: `04-migration-scripts/master/vessel_category_metric_definition_migration.sql`

- **Legacy Path**: `synergy_master.public.CargoFormulas`
- **New Path**: `smac_master_migration.vessel.vessel_category_metric_definition`

## Business Key

- **Business Key**: `vessel_category_id`
- **Source (orchestration)**: Cargo Formulas (`CargoFormulas` → `vessel_category_metric_definition`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- Source: `synergy_master.public.\"CargoFormulas\"`
- `vessel_category_id` mapped via `vessel_category_id_mapping` → `migration.table_mappings` (categories)
- `code`/`name` generated from `vessel_category_id` — SAC has no code/name columns
- `status` hardcoded Active (0) — no `deleted_at` in SAC
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_category_metric_definition` before insert (full table reload).
- Orchestration dependencies: `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_category_id_mapping` | Check for duplicate UUIDs in source table | `legacy_category_id`, `new_category_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_category_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_category_id, new_category_id
- **migration.table_mappings**: target_table=categories

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint AS legacy_category_id,
    target_id AS new_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `vessel_category_id` | bigint | `code` | character varying | `'CF_' || vessel_category_id` | Generated code |
| 3 | `vessel_category_id` | bigint | `name` | character varying | `'Cargo Formula for Category ' || vessel_category_id` | Generated name |
| 4 | `—` | — | `description` | text | `NULL` | Not in SAC source |
| 5 | `formula_for_dwt` | text | `dwt_expression` | text | `TRIM(formula_for_dwt)` | Direct copy |
| 6 | `dwt_required_to_round_to_zero_if_negative` | boolean | `is_dwt_round_to_zero` | boolean | Direct copy | Direct boolean |
| 7 | `cargo_UOM` | text | `cargo_uom` | text | `TRIM(cargo_UOM)` | Direct copy |
| 8 | `formula_for_cargo_UOM` | text | `cargo_capacity_expression` | text | `TRIM(formula_for_cargo_UOM)` | Direct copy |
| 9 | `cargo_UOM_required_to_round_to_zero_if_negative` | boolean | `is_cargo_capacity_round_to_zero` | boolean | Direct copy | Direct boolean |
| 10 | `vessel_category_id` | bigint | `vessel_category_id` | uuid | Map via `vessel_category_id_mapping` | NULL when unmapped |
| 11 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 12 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 13 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 14 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 15 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 16 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 17 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No deleted_at in SAC |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 21 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 22 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |
| 23 | `—` | — | `tags` | text[] | `NULL` | Not populated |

**SAC columns not migrated:** None from dblink SELECT — all selected columns mapped.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Category ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_category_id, new_category_id`
**migration.table_mappings**: `target_table='categories'`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint AS legacy_category_id,
    target_id AS new_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_category_metric_definition_migration.sql`

## Validation

- Run `05-validation/master/vessel_category_metric_definition_validation.sql` if available
- Run `06-rollback/master/vessel_category_metric_definition_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
