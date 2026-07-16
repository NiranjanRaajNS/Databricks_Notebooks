# Table Mapping: nationalities → nationalities

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: nationalities
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: nationalities
- **Source Script**: `04-migration-scripts/master/nationalities_migration.sql`

- **Legacy Path**: `synergy_master.public.nationalities`
- **New Path**: `smac_master_migration.public.nationalities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Nationalities (`nationalities` → `nationalities`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.nationalities` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `c.iso_code`, `country_name`, `country_id` | - | - |

### `country_id_mapping`

- **Output columns**: c.iso_code, country_name, country_id

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    c.iso_code,
    c.name as country_name,
    c.id as country_id
FROM public.countries c
WHERE c.deleted_at IS NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | uuid, id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.uuid) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'nationalities'::VARCHAR(100), legacy_data.id::text, current_... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | iso_code, name | - | code | - | generate_meaningful_code() | COALESCE( NULLIF(TRIM(legacy_data.iso_code), ''), generate_meaningful_code(TRIM(legacy_data.name), '') ) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | country_id | - | country_id_mapping.country_id as country_id | country_id_mapping.country_id |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 12 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 13 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 14 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 15 | iso_code, name | - | tags | - | CASE WHEN LOWER(TRIM(COALESCE(legacy_data.iso_code, ''))) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), ''... | CASE WHEN LOWER(TRIM(COALESCE(legacy_data.iso_code, ''))) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), ''... |
| 16 | name, iso_code | - | status | - | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(TRIM(COALESCE(legacy_dat... | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(TRIM(COALESCE(legacy_dat... |
| 17 | deleted_at | - | workflow_status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status |
| 18 | - | - | defined_by | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer as workflow_status |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `c.iso_code, country_name, country_id`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    c.iso_code,
    c.name as country_name,
    c.id as country_id
FROM public.countries c
WHERE c.deleted_at IS NULL;
```

Full migration context: `04-migration-scripts/master/nationalities_migration.sql`

## Validation

- Run `05-validation/master/nationalities_validation.sql` if available
- Run `06-rollback/master/nationalities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
