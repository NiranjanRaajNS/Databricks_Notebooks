# Table Mapping: cba_wage_amount_experience_tiers → cba_wage_amount_experience_tiers

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_amount_experience_tiers
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_amount_experience_tiers
- **Source Script**: `04-migration-scripts/master/cba_wage_amount_experience_tiers_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_amount_experience_tiers`
- **New Path**: `smac_master_migration.crewing.cba_wage_amount_experience_tiers`

## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `experience_tier_id`)
- **Source (orchestration)**: CBA Wage Amount Experience Tiers (`cba_wage_amount_experience_tiers` → `cba_wage_amount_experience_tiers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates cba_wage_amount_experience_tiers from synergy_master.wages schema. Depends on cba_wage_charts. Preserves identifier/uuid when available.

## Special Considerations

- Source table has id column (UUID) - uses migration.resolve_target_id() to preserve legacy UUID with idempotency support
- Script performs `TRUNCATE TABLE crewing.cba_wage_amount_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `derived_wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `cba_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

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

### `cba_wage_scales_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cba_wage_scales

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_amount_experience_tiers'::VARCHAR(100), source.id::text, current_database()::text::... |
| 2 | derived | - | experience_tier_id | - | et.id as experience_tier_id | et.id |
| 3 | derived | - | pay | - | source.pay | source.pay |
| 4 | derived | - | applicable | - | source.applicable | source.applicable |
| 5 | derived | - | basic_wage_component_id | - | wc_mapping.new_id as basic_wage_component_id | wc_mapping.new_id |
| 6 | derived | - | derived_wage_component_id | - | dwc_mapping.new_id as derived_wage_component_id | dwc_mapping.new_id |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | derived | - | status | - | CASE WHEN source.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN source.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 13 | derived | - | created_at | - | COALESCE(source.created_at, NOW()) as created_at | COALESCE(source.created_at, NOW()) |
| 14 | derived | - | updated_at | - | source.updated_at as updated_at | source.updated_at |
| 15 | derived | - | deleted_at | - | source.deleted_at as deleted_at | source.deleted_at |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_experience_tiers`
- `crewing.cba_wage_scales`
- `crewing.derived_wage_components`
- `crewing.wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

### 2. Derived Wage Components ID Mapping
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

### 3. Cba Wage Scales ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cba_wage_scales'`

```sql
CREATE TEMP TABLE cba_wage_scales_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cba_wage_scales'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_wage_amount_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_amount_experience_tiers_validation.sql` if available
- Run `06-rollback/master/cba_wage_amount_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
