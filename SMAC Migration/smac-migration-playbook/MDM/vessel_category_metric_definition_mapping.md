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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates CargoFormulas from synergy_master.public.CargoFormulas to smac_master_migration.vessel.vessel_category_metric_definition. Preserves legacy UUID as target id (Pattern A). Maps vessel_category_id from bigint to uuid via migration.table_mappings (categories table). Generates code and name from vessel_category_id. Maps formula fields: formula_for_dwt→dwt_expression, formula_for_cargo_UOM→cargo_capacity_expression. Maps boolean flags: dwt_required_to_round_to_zero_if_negative→is_dwt_round_to_zero, cargo_UOM_required_to_round_to_zero_if_negative→is_cargo_capacity_round_to_zero. Uses standardized SMAC audit_info structure without legacy_id (since UUID is preserved). Requires categories table to be migrated first.

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'CargoFormulas'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100),... |
| 2 | derived | - | code | - | 'CF_' || vessel_category_id::text AS code | 'CF_' || vessel_category_id::text |
| 3 | derived | - | name | - | 'Cargo Formula for Category ' || vessel_category_id::text AS name | 'Cargo Formula for Category ' || vessel_category_id::text |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | derived | - | dwt_expression | - | TRIM(formula_for_dwt) AS dwt_expression | TRIM(formula_for_dwt) |
| 6 | derived | - | is_dwt_round_to_zero | - | dwt_required_to_round_to_zero_if_negative AS is_dwt_round_to_zero | dwt_required_to_round_to_zero_if_negative |
| 7 | derived | - | cargo_uom | - | TRIM(cargo_UOM) AS cargo_uom | TRIM(cargo_UOM) |
| 8 | derived | - | cargo_capacity_expression | - | TRIM(formula_for_cargo_UOM) AS cargo_capacity_expression | TRIM(formula_for_cargo_UOM) |
| 9 | derived | - | is_cargo_capacity_round_to_zero | - | cargo_UOM_required_to_round_to_zero_if_negative AS is_cargo_capacity_round_to_zero | cargo_UOM_required_to_round_to_zero_if_negative |
| 10 | derived | - | vessel_category_id | - | vc_map.new_category_id AS vessel_category_id | vc_map.new_category_id |
| 11 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 12 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 13 | - | - | parent_id | - | NULL | NULL::uuid |
| 14 | derived | - | version | - | 1 as version | 1 |
| 15 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | derived | - | status | - | 0 as status | 0 |
| 18 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 19 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 20 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 21 | - | - | archived_at | - | NULL | NULL::timestamp |
| 22 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 23 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
