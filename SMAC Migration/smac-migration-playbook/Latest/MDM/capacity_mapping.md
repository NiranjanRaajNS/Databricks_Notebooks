# Table Mapping: vessel_particulars → capacity

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_particulars
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: capacity
- **Source Script**: `04-migration-scripts/master/capacity_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_particulars`
- **New Path**: `smac_master_migration.vessel.capacity`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Capacity Types (`vessel_particulars` → `capacity`)

## Migration Notes

- Source is `information_schema.columns` from `vessel_particulars` where `column_name LIKE '%_capacity%'`
- Source_id = `column_name` text; `migration.resolve_target_id()` with `p_target_id = NULL`
- `name`/`description` mapped via CASE for known capacity columns; else `INITCAP(REPLACE(column_name, '_', ' '))`
- `is_mandatory = true` only for `fuel_oil_capacity`
- Some capacities get `status = 3` (Deleted) per script logic

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.capacity` before insert (full table reload).

## ID Mappings

Intermediate lookup tables from the migration script.

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `capacity_columns` | Source column discovery | `column_name`, `row_num` | - | `synergy_vessel` |

### `capacity_columns`

- **Purpose**: Discover `*_capacity` columns from `vessel_particulars` via information_schema
- **Output columns**: column_name, row_num
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE capacity_columns AS
SELECT
    column_name,
    ROW_NUMBER() OVER (ORDER BY column_name) AS row_num
FROM dblink('synergy_vessel',
    'SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = ''public''
       AND table_name = ''vessel_particulars''
       AND column_name LIKE ''%_capacity%''
     ORDER BY column_name'
) AS cols(column_name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `column_name` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = `column_name`; `p_target_id = NULL` | Idempotent UUID per column name |
| 2 | `column_name` | text | `code` | text | `generate_meaningful_code(name, NULL)` | Generated from display name |
| 3 | `column_name` | text | `name` | text | CASE map (e.g. `grain_capacity` → `'Grain Capacity'`) or `INITCAP(REPLACE(column_name, '_', ' '))` | Display name |
| 4 | `column_name` | text | `description` | text | Same CASE mapping as name | Description text |
| 5 | `—` | — | `default_uom_id` | uuid | `NULL` | Not populated |
| 6 | `column_name` | text | `is_mandatory` | boolean | `true` only when `column_name = 'fuel_oil_capacity'`; else `false` | Business rule |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 8 | `—` | — | `parent_id` | uuid | `NULL` | No parent in source |
| 9 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 10 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No row-level timestamps |
| 11 | `—` | — | `updated_at` | timestamp without time zone | `NULL` | Not populated |
| 12 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Not populated |
| 13 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not populated |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in source |
| 15 | `—` | — | `level` | numeric | Hardcoded `0` | No level in source |
| 16 | `column_name` | text | `tags` | text[] | Column name as tag (`ballistic_capacity` → `ballast_capacity`) | Derived search tag |
| 17 | `column_name` | text | `status` | integer | Specific columns → Deleted (3); else `DEFAULT_STATUS` from `constants.sql` | Per-column business rule |
| 18 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 19 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/capacity_migration.sql`

## Validation

- Run `05-validation/master/capacity_validation.sql` if available
- Run `06-rollback/master/capacity_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
