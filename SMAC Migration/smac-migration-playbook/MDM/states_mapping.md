# Table Mapping: states → states

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: states
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: states
- **Source Script**: `04-migration-scripts/master/states_migration.sql`

- **Legacy Path**: `synergy_master.public.states`
- **New Path**: `smac_master_migration.public.states`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: States (`states` → `states`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.states` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | Check if any mapp | `DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint`, `tm.target_id` | `migration.table_mappings` (see SQL) | - |

### `country_id_mapping`

- **Purpose**: Check if any mapp
- **Output columns**: DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint, tm.target_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint,
    tm.target_id
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL
ORDER BY tm.source_id::bigint, tm.target_id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'states'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'publi... |
| 2 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 3 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(name), TRIM(identifier::text)) |
| 4 | derived | - | country_id | - | country_map.target_id as country_id | country_map.target_id |
| 5 | derived | - | description | - | NULL as description | NULL |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 16 | derived | - | level | - | (ROW_NUMBER() OVER (ORDER BY TRIM(name))::numeric / 1.0)::numeric(10,1) as level | (ROW_NUMBER() OVER (ORDER BY TRIM(name))::numeric / 1.0)::numeric(10,1) |
| 17 | derived | - | tags | - | ARRAY[]::text[] as tags | ARRAY[]::text[] |
| 18 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) <> '' AND TRIM(legacy_data.created_by_id) ~ '^[0-9a-f]{8}-[0-9a-f... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Purpose**: Check if any mapp
**Output columns**: `DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint, tm.target_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint,
    tm.target_id
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL
ORDER BY tm.source_id::bigint, tm.target_id;
```

Full migration context: `04-migration-scripts/master/states_migration.sql`

## Validation

- Run `05-validation/master/states_validation.sql` if available
- Run `06-rollback/master/states_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
