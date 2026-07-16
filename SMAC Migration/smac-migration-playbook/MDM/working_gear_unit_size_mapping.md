# Table Mapping: working_gear_unit_size → working_gear_unit_size

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: working_gear_unit_size
- **Source Script**: `04-migration-scripts/master/working_gear_unit_size_migration.sql`

- **Legacy Path**: `synergy_manning_po.public.ppe_component_masters.measurement (JSONB)`
- **New Path**: `smac_master_migration.crewing.working_gear_unit_size`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Working Gear Unit Size (`ppe_component_masters` → `working_gear_unit_size`)

## Migration Notes

- Create one record per measurement entry
- Link to working_gear via working_gear_id (using migration.table_mappings)
- Generate code from name (uppercase with underscores)
- Pack created_by/updated_by/deleted_by into audit_info JSON
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates working_gear_unit_size table. Extracts measurement JSONB array from ppe_component_masters. Creates one record per measurement entry. Links to working_gear via working_gear_id using migration.table_mappings. Generates new UUIDs for unit size records. Uses constant tenant_id. Stores full measurement JSON in audit_info for reference.

## Special Considerations

- Extract measurement JSONB array from ppe_component_masters
- Script performs `TRUNCATE TABLE crewing.working_gear_unit_size` before insert (full table reload).
- Orchestration dependencies: `working_gear`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `working_gear_id_mapping` | Check f | `legacy_name`, `working_gear_id` | - | `synergy_manning_po` |

### `working_gear_id_mapping`

- **Purpose**: Check f
- **Output columns**: legacy_name, working_gear_id
- **dblink connection**: `synergy_manning_po`

```sql
CREATE TEMP TABLE working_gear_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(legacy_data.name)))
    UPPER(TRIM(legacy_data.name)) AS legacy_name,
    wg.id AS working_gear_id
FROM dblink('synergy_manning_po',
    'SELECT DISTINCT name FROM public.ppe_component_masters WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS legacy_data(name text)
JOIN crewing.working_gear wg ON UPPER(TRIM(wg.name)) = UPPER(TRIM(legacy_data.name))
WHERE TRIM(legacy_data.name) != '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_working_gear_id, row_num | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning_po'::VARCHAR(100), 'public'::VARCHAR(100), 'ppe_component_masters'::VARCHAR(100), (s.legacy_working_gear_id::text || '_' || s.row_n... |
| 2 | name, code_from_json | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(s.name), TRIM(s.code_from_json)) |
| 3 | name, size, code_from_json | - | name | - | COALESCE( NULLIF(TRIM(s.name), ''), NULLIF(TRIM(s.size), ''), NULLIF(TRIM(s.code_from_json), '') ) AS name | COALESCE( NULLIF(TRIM(s.name), ''), NULLIF(TRIM(s.size), ''), NULLIF(TRIM(s.code_from_json), '') ) |
| 4 | - | - | description | - | NULL | NULL::text |
| 5 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 6 | working_gear_id | - | working_gear_id | - | s.working_gear_id AS working_gear_id | s.working_gear_id |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 13 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(s.updated_at, NOW()) AS updated_at | COALESCE(s.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | - | - | tags | - | NULL | NULL::text[] |
| 18 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN s.cre... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Working Gear ID Mapping
**Purpose**: Check f
**Output columns**: `legacy_name, working_gear_id`
**dblink**: `synergy_manning_po`

```sql
CREATE TEMP TABLE working_gear_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(legacy_data.name)))
    UPPER(TRIM(legacy_data.name)) AS legacy_name,
    wg.id AS working_gear_id
FROM dblink('synergy_manning_po',
    'SELECT DISTINCT name FROM public.ppe_component_masters WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS legacy_data(name text)
JOIN crewing.working_gear wg ON UPPER(TRIM(wg.name)) = UPPER(TRIM(legacy_data.name))
WHERE TRIM(legacy_data.name) != '';
```

Full migration context: `04-migration-scripts/master/working_gear_unit_size_migration.sql`

## Validation

- Run `05-validation/master/working_gear_unit_size_validation.sql` if available
- Run `06-rollback/master/working_gear_unit_size_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
