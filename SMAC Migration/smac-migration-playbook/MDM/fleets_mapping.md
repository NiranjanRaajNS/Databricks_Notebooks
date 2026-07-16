# Table Mapping: fleet_master → fleets

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: fleet_master
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fleets
- **Source Script**: `04-migration-scripts/master/fleets_migration.sql`

- **Legacy Path**: `synergy_vessel.public.fleet_master`
- **New Path**: `smac_master_migration.vessel.fleets`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Fleets (`fleet_master` → `fleets`)

## Migration Notes

- Preserve legacy id (UUID) as new id
- Record legacy id (uuid) → new uuid (same) in migration.table_mappings
- Map company_id (bigint) → company_id (uuid) via migration.table_mappings
- Map department_id (integer) → fdl_department_id (uuid) via migration.table_mappings
- Convert status (varchar) → status (integer): Active=0, Draft=1, Inactive=2, Deleted=3
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrate ALL records including deleted ones (deleted_at preserved, status = 3 when deleted_at IS NOT NULL)
- Migrates fleet_master preserving UUID id. Maps company_id (bigint→uuid) and department_id (integer→uuid). Converts status (varchar→integer). Filters deleted records (deleted_at IS NULL).

## Special Considerations

- Use DISTINCT ON to prevent duplicates when multiple mappings exist for the same legacy_id
- Script performs `TRUNCATE TABLE vessel.fleets` before insert (full table reload).
- Orchestration dependencies: `companies`, `fdl_departments`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | Check for duplicate UUIDs in source table | `legacy_company_id`, `new_company_id`, `company_code` | `?.?.ship_management_companies` → `?.public.companies` | - |
| `fdl_department_id_mapping` | FK lookup | `legacy_department_id`, `new_fdl_department_id`, `department_code` | `migration.table_mappings` (see SQL) | - |
| `fleet_type_mapping` | FK lookup | `fleet_type_code`, `fleet_type_id` | - | - |

### `company_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_company_id, new_company_id, company_code
- **migration.table_mappings**: source_table=ship_management_companies, target_schema=public, target_table=companies

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint as legacy_company_id,
    tm.target_id::uuid as new_company_id,
    c.code as company_code
FROM migration.table_mappings tm
LEFT JOIN public.companies c ON c.id = tm.target_id::uuid
WHERE tm.target_table = 'companies'
  AND tm.target_schema = 'public'
  AND tm.source_table ='ship_management_companies'
  AND tm.target_db = COALESCE(:'TARGET_DB', current_database())
ORDER BY tm.source_id::bigint, tm.target_id;
```

### `fdl_department_id_mapping`

- **Output columns**: legacy_department_id, new_fdl_department_id, department_code
- **migration.table_mappings**: target_table=fdl_departments

```sql
CREATE TEMP TABLE fdl_department_id_mapping AS
SELECT DISTINCT ON (tm.source_id::integer)
    tm.source_id::integer as legacy_department_id,
    tm.target_id::uuid as new_fdl_department_id,
    d.code as department_code
FROM migration.table_mappings tm
LEFT JOIN vessel.fdl_departments d ON d.id = tm.target_id::uuid
WHERE tm.target_table = 'fdl_departments'
  AND tm.target_db = current_database()
ORDER BY tm.source_id::integer, tm.target_id;
```

### `fleet_type_mapping`

- **Output columns**: fleet_type_code, fleet_type_id

```sql
CREATE TEMP TABLE fleet_type_mapping AS
SELECT
    code as fleet_type_code,
    id as fleet_type_id
FROM vessel.fleet_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'fleet_master'::VARCHAR(100), fdp.id::text, current_database()::text::VARCHAR(100), 'vessel'... |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(fdp.name), fdp.id::text) |
| 3 | derived | - | name | - | LEFT( CASE WHEN fdp.calculated_prefix != '' AND TRIM(fdp.name) LIKE fdp.calculated_prefix || '%' THEN TRIM( REGEXP_REPLACE( SUBSTRING(TRIM(fdp.name) FROM LENGTH(fdp.calculated_p... | LEFT( CASE WHEN fdp.calculated_prefix != '' AND TRIM(fdp.name) LIKE fdp.calculated_prefix || '%' THEN TRIM( REGEXP_REPLACE( SUBSTRING(TRIM(fdp.name) FROM LENGTH(fdp.calculated_p... |
| 4 | derived | - | description | - | NULL AS description | NULL |
| 5 | derived | - | company_id | - | fdp.new_company_id AS company_id | fdp.new_company_id |
| 6 | derived | - | fdl_department_id | - | fdp.new_fdl_department_id AS fdl_department_id | fdp.new_fdl_department_id |
| 7 | derived | - | fleet_type_id | - | fdp.fleet_type_id AS fleet_type_id | fdp.fleet_type_id |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 10 | derived | - | version | - | 1 AS version | 1 |
| 11 | derived | - | created_at | - | COALESCE(fdp.created_at, NOW()) AS created_at | COALESCE(fdp.created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(fdp.updated_at, NOW()) AS updated_at | COALESCE(fdp.updated_at, NOW()) |
| 13 | derived | - | deleted_at | - | fdp.deleted_at AS deleted_at | fdp.deleted_at |
| 14 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 15 | derived | - | level | - | NULL AS level | NULL |
| 16 | derived | - | prefix | - | fdp.calculated_prefix AS prefix | fdp.calculated_prefix |
| 17 | derived | - | tags | - | NULL AS tags | NULL |
| 18 | derived | - | status | - | CASE WHEN fdp.deleted_at IS NOT NULL THEN 3 WHEN fdp.status IS NULL THEN 0 WHEN UPPER(TRIM(fdp.status)) = 'ACTIVE' OR TRIM(fdp.status) = '0' THEN 0 WHEN UPPER(TRIM(fdp.status)) ... | CASE WHEN fdp.deleted_at IS NOT NULL THEN 3 WHEN fdp.status IS NULL THEN 0 WHEN UPPER(TRIM(fdp.status)) = 'ACTIVE' OR TRIM(fdp.status) = '0' THEN 0 WHEN UPPER(TRIM(fdp.status)) ... |
| 19 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 20 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 21 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, CASE WHEN fdp.audit_info IS NOT NULL AND fdp.aud... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.fdl_departments`
- `vessel.fleet_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_company_id, new_company_id, company_code`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint as legacy_company_id,
    tm.target_id::uuid as new_company_id,
    c.code as company_code
FROM migration.table_mappings tm
LEFT JOIN public.companies c ON c.id = tm.target_id::uuid
WHERE tm.target_table = 'companies'
  AND tm.target_schema = 'public'
  AND tm.source_table ='ship_management_companies'
  AND tm.target_db = COALESCE(:'TARGET_DB', current_database())
ORDER BY tm.source_id::bigint, tm.target_id;
```

### 2. Fdl Department ID Mapping
**Output columns**: `legacy_department_id, new_fdl_department_id, department_code`
**migration.table_mappings**: `target_table='fdl_departments'`

```sql
CREATE TEMP TABLE fdl_department_id_mapping AS
SELECT DISTINCT ON (tm.source_id::integer)
    tm.source_id::integer as legacy_department_id,
    tm.target_id::uuid as new_fdl_department_id,
    d.code as department_code
FROM migration.table_mappings tm
LEFT JOIN vessel.fdl_departments d ON d.id = tm.target_id::uuid
WHERE tm.target_table = 'fdl_departments'
  AND tm.target_db = current_database()
ORDER BY tm.source_id::integer, tm.target_id;
```

### 3. Fleet Type ID Mapping
**Output columns**: `fleet_type_code, fleet_type_id`

```sql
CREATE TEMP TABLE fleet_type_mapping AS
SELECT
    code as fleet_type_code,
    id as fleet_type_id
FROM vessel.fleet_types;
```

Full migration context: `04-migration-scripts/master/fleets_migration.sql`

## Validation

- Run `05-validation/master/fleets_validation.sql` if available
- Run `06-rollback/master/fleets_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
