# Table Mapping: ranks → ranks

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ranks
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: ranks
- **Source Script**: `04-migration-scripts/master/ranks_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks`
- **New Path**: `smac_master_migration.public.ranks`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## Migration Notes

- Preserve legacy identifier (UUID) as id using migration.resolve_target_id()
- Map officer_type (bigint) to UUID via direct enum.officertype table query
- Map rank_category (bigint) to UUID via direct enum.rankcategory table query
- Map rank_type (bigint) to UUID via direct enum.rank_type table query
- Map department (text) to rank_department_id (UUID) via rank_departments lookup by name
- Map msm_position (text) to msmposition_id (UUID) via msm_positions lookup by name
- Map position (numeric) to level (numeric) - direct mapping
- Map superior_rank_id (bigint) from source table to UUID via ranks self-reference using migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates ranks table preserving identifier UUID as id, maps rank_category_id, rank_type_id, and department_id

## Special Considerations

- Script performs `TRUNCATE TABLE public.ranks` before insert (full table reload).
- Orchestration dependencies: `msm_positions`, `rank_categories`, `rank_types`, `rank_departments`, `superior_ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `superior_rank_lookup` | FK lookup | `legacy_rank_id`, `legacy_rank_identifier` | - | `synergy_master` |
| `msm_position_id_mapping` | FK lookup | `msm_position_text`, `msm_position_id` | `migration.table_mappings` (see SQL) | - |

### `superior_rank_lookup`

- **Output columns**: legacy_rank_id, legacy_rank_identifier
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE superior_rank_lookup AS
SELECT DISTINCT
    d.id AS legacy_rank_id,
    d.identifier AS legacy_rank_identifier
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS d(id bigint, identifier uuid);
```

### `msm_position_id_mapping`

- **Output columns**: msm_position_text, msm_position_id
- **migration.table_mappings**: target_table=msm_positions

```sql
CREATE TEMP TABLE msm_position_id_mapping AS
SELECT DISTINCT
    tm.source_id AS msm_position_text,
    tm.target_id AS msm_position_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'msm_positions'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ranks'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'public... |
| 2 | short_code | - | code | - | COALESCE(TRIM(legacy_data.short_code), '') AS code | COALESCE(TRIM(legacy_data.short_code), '') |
| 3 | name | - | name | - | COALESCE(legacy_data.name, 'UNKNOWN') AS name | COALESCE(legacy_data.name, 'UNKNOWN') |
| 4 | derived | - | officer_type_id | - | ot.identifier AS officer_type_id | ot.identifier |
| 5 | derived | - | rank_category_id | - | rcm.identifier AS rank_category_id | rcm.identifier |
| 6 | derived | - | rank_type_id | - | rtm.identifier AS rank_type_id | rtm.identifier |
| 7 | derived | - | rank_department_id | - | rd.id AS rank_department_id | rd.id |
| 8 | derived | - | msmposition_id | - | mpm.msm_position_id AS msmposition_id | mpm.msm_position_id |
| 9 | position | - | level | - | legacy_data.position AS level | legacy_data.position |
| 10 | derived | - | superior_rank_id | - | NULL AS superior_rank_id | NULL |
| 11 | short_code | - | crew_type | - | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.short_code, ''))) = 'SR' THEN 1 ELSE 0 END AS crew_type | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.short_code, ''))) = 'SR' THEN 1 ELSE 0 END |
| 12 | is_lowest_rank | - | is_entry_level | - | COALESCE(legacy_data.is_lowest_rank, false) AS is_entry_level | COALESCE(legacy_data.is_lowest_rank, false) |
| 13 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 14 | derived | - | version | - | 1 AS version | 1 |
| 15 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... |
| 18 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 19 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 20 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 21 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 22 | short_code, name | - | tags | - | CASE WHEN COALESCE(TRIM(legacy_data.short_code), '') != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '_'), '.'... | CASE WHEN COALESCE(TRIM(legacy_data.short_code), '') != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '_'), '.'... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Superior Rank ID Mapping
**Output columns**: `legacy_rank_id, legacy_rank_identifier`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE superior_rank_lookup AS
SELECT DISTINCT
    d.id AS legacy_rank_id,
    d.identifier AS legacy_rank_identifier
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS d(id bigint, identifier uuid);
```

### 2. Msm Position ID Mapping
**Output columns**: `msm_position_text, msm_position_id`
**migration.table_mappings**: `target_table='msm_positions'`

```sql
CREATE TEMP TABLE msm_position_id_mapping AS
SELECT DISTINCT
    tm.source_id AS msm_position_text,
    tm.target_id AS msm_position_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'msm_positions'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/ranks_migration.sql`

## Validation

- Run `05-validation/master/ranks_validation.sql` if available
- Run `06-rollback/master/ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
