# Table Mapping: cba_wage_scales → cba_wage_scales

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: cba_wage_scales
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_wage_scales
- **Source Script**: `04-migration-scripts/master/cba_wage_scales_migration.sql`

- **Legacy Path**: `synergy_master.wages.cba_wage_scales`
- **New Path**: `smac_master_migration.crewing.cba_wage_scales`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: CBA Wage Scales (`cba_wage_scales` → `cba_wage_scales`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- cba_wage_chart_id: crewing.cba_wage_charts (via table_mappings)
- position_id: public.positions (via table_mappings)
- rank_id: public.ranks (via table_mappings)
- Using CASCADE because other tables (cba_wage_amounts, cba_wage_amount_ot, etc.) have foreign keys referencing this table
- Migrates cba_wage_scales from synergy_master.wages schema. Preserves identifier/uuid when available.

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_wage_scales` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_charts_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `positions_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cba_wage_charts_id_mapping`

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

### `positions_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=positions

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'cba_wage_scales'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | derived | - | cba_wage_chart_id | - | COALESCE(cba_chart_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as cba_wage_chart_id | COALESCE(cba_chart_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | position_id | - | position_mapping.new_id as position_id | position_mapping.new_id |
| 4 | derived | - | rank_id | - | rank_mapping.new_id as rank_id | rank_mapping.new_id |
| 5 | with_superior_certificate | - | with_superior_certificate | - | COALESCE(legacy_data.with_superior_certificate, false) as with_superior_certificate | COALESCE(legacy_data.with_superior_certificate, false) |
| 6 | wage_defined_by_experience | - | wage_defined_by_experience | - | COALESCE(legacy_data.wage_defined_by_experience, false) as wage_defined_by_experience | COALESCE(legacy_data.wage_defined_by_experience, false) |
| 7 | scope | - | scope | - | TRIM(legacy_data.scope) as scope | TRIM(legacy_data.scope) |
| 8 | cycle | - | cycle | - | TRIM(legacy_data.cycle) as cycle | TRIM(legacy_data.cycle) |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_charts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Charts ID Mapping
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

### 2. Positions ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='positions'`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

### 3. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_wage_scales_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_scales_validation.sql` if available
- Run `06-rollback/master/cba_wage_scales_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
