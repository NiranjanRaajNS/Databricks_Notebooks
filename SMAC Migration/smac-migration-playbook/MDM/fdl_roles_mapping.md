# Table Mapping: vessel_fdl_roles → fdl_roles

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_fdl_roles
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_roles
- **Source Script**: `04-migration-scripts/master/fdl_roles_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_fdl_roles`
- **New Path**: `smac_master_migration.vessel.fdl_roles`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Fdl Roles (`vessel_fdl_roles` → `fdl_roles`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_fdl_roles preserving identifier/uuid UUID as id. Requires fdl_departments table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_roles` before insert (full table reload).
- Orchestration dependencies: `fdl_departments`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `role_department_mapping` | FK lookup | `role_identifier`, `legacy_department_id` | - | `synergy_vessel` |
| `fdl_departments_id_mapping` | FK lookup | `legacy_department_id`, `new_fdl_department_id` | `migration.table_mappings` (see SQL) | - |

### `role_department_mapping`

- **Output columns**: role_identifier, legacy_department_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE role_department_mapping AS
SELECT DISTINCT ON (role_id)
    role_id AS role_identifier,
    department_id AS legacy_department_id
FROM (
    SELECT
        vf.role_id,
        vf.department_id,
        COUNT(*) AS dept_count,
        ROW_NUMBER() OVER (PARTITION BY vf.role_id ORDER BY COUNT(*) DESC, vf.department_id) AS rn
    FROM dblink('synergy_vessel',
        'SELECT role_id, department_id
         FROM public.vessel_fdl
         WHERE role_id IS NOT NULL AND department_id IS NOT NULL'
    ) AS vf(
        role_id uuid,
        department_id integer
    )
    GROUP BY vf.role_id, vf.department_id
) ranked
WHERE rn = 1;
```

### `fdl_departments_id_mapping`

- **Output columns**: legacy_department_id, new_fdl_department_id
- **migration.table_mappings**: target_table=fdl_departments

```sql
CREATE TEMP TABLE fdl_departments_id_mapping AS
SELECT
    source_id::bigint AS legacy_department_id,
    target_id::uuid AS new_fdl_department_id
FROM migration.table_mappings
WHERE target_table = 'fdl_departments'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | code | - | See source script | See source script |
| 3 | - | - | name | - | See source script | See source script |
| 4 | - | - | description | - | See source script | See source script |
| 5 | - | - | fdl_department_id | - | See source script | See source script |
| 6 | - | - | tenant_id | - | See source script | See source script |
| 7 | - | - | parent_id | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | defined_by | - | See source script | See source script |
| 10 | - | - | workflow_status | - | See source script | See source script |
| 11 | - | - | status | - | See source script | See source script |
| 12 | - | - | created_at | - | See source script | See source script |
| 13 | - | - | updated_at | - | See source script | See source script |
| 14 | - | - | deleted_at | - | See source script | See source script |
| 15 | - | - | archived_at | - | See source script | See source script |
| 16 | - | - | audit_info | - | See source script | See source script |
| 17 | - | - | tags | - | See source script | See source script |
| 18 | - | - | scope | - | See source script | See source script |
| 19 | - | - | level | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Role Department ID Mapping
**Output columns**: `role_identifier, legacy_department_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE role_department_mapping AS
SELECT DISTINCT ON (role_id)
    role_id AS role_identifier,
    department_id AS legacy_department_id
FROM (
    SELECT
        vf.role_id,
        vf.department_id,
        COUNT(*) AS dept_count,
        ROW_NUMBER() OVER (PARTITION BY vf.role_id ORDER BY COUNT(*) DESC, vf.department_id) AS rn
    FROM dblink('synergy_vessel',
        'SELECT role_id, department_id
         FROM public.vessel_fdl
         WHERE role_id IS NOT NULL AND department_id IS NOT NULL'
    ) AS vf(
        role_id uuid,
        department_id integer
    )
    GROUP BY vf.role_id, vf.department_id
) ranked
WHERE rn = 1;
```

### 2. Fdl Departments ID Mapping
**Output columns**: `legacy_department_id, new_fdl_department_id`
**migration.table_mappings**: `target_table='fdl_departments'`

```sql
CREATE TEMP TABLE fdl_departments_id_mapping AS
SELECT
    source_id::bigint AS legacy_department_id,
    target_id::uuid AS new_fdl_department_id
FROM migration.table_mappings
WHERE target_table = 'fdl_departments'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/fdl_roles_migration.sql`

## Validation

- Run `05-validation/master/fdl_roles_validation.sql` if available
- Run `06-rollback/master/fdl_roles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
