# Table Mapping: cba_wage_experience_tiers → cba_wage_experience_tiers

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: cba_wage_experience_tiers
- **Source Script**: `04-migration-scripts/master/cba_wage_experience_tiers_migration.sql`


## Business Key

- **Composite Key**: (`cba_wage_chart_id`, `experience_tier_id`)
- **Source (orchestration)**: CBA Wage Experience Tiers (`cba_wage_amount_experience_tiers` → `cba_wage_experience_tiers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates cba_wage_experience_tiers from synergy_master.wages.cba_wage_amount_experience_tiers. Depends on cba_wage_charts. Preserves identifier/uuid when available.

## Special Considerations

- id is already UUID in source SAC - preserve legacy UUID (generate new if NULL). identifier and uuid columns are NOT available.
- Script performs `TRUNCATE TABLE crewing.cba_wage_experience_tiers` before insert (full table reload).
- Orchestration dependencies: `cba_wage_charts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cba_wage_scales_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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
| 1 | range_start, range_end, id | - | id | - | migration.resolve_target_id() | DISTINCT ON (cws_mapping.new_id, legacy_data.range_start::numeric(10,2), legacy_data.range_end::numeric(10,2)) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wage... |
| 2 | derived | - | cba_wage_scale_id | - | COALESCE(cws_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as cba_wage_scale_id | COALESCE(cws_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | range_start | - | range_start | - | legacy_data.range_start as range_start | legacy_data.range_start |
| 4 | range_end | - | range_end | - | legacy_data.range_end as range_end | legacy_data.range_end |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | legacy_data.updated_at as updated_at | legacy_data.updated_at |
| 13 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN legac... |
| 14 | derived | - | level | - | 0 as level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_wage_scales`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cba Wage Scales ID Mapping
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

Full migration context: `04-migration-scripts/master/cba_wage_experience_tiers_migration.sql`

## Validation

- Run `05-validation/master/cba_wage_experience_tiers_validation.sql` if available
- Run `06-rollback/master/cba_wage_experience_tiers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
