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

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated via `generate_meaningful_code(display_name/name, identifier::text)`
- `fdl_department_id` mapped via `role_department_mapping` + `fdl_departments_id_mapping`; insurance roles override to Insurance FDL department
- `status` hardcoded Active (0); SAC has no `deleted_at` column
- `created_at`/`updated_at` from SAC `create_at`/`update_at` with infinity/invalid date handling
- `tags` derived from `display_name` (lowercase snake, UPPER_SNAKE, UPPERCASE); post-migration UPDATE adds `group_head` tag
- `scope` hardcoded `2` (vessel level) for primary INSERT
- Script contains 10 INSERT blocks (primary SAC + fleet-level seed roles); column mapping documents primary legacy INSERT only
- Requires `fdl_departments` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

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
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `role_display_name`, `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(LEFT(COALESCE(display_name, name, 'UNKNOWN'), 255), identifier::text)` | Generated from display name + identifier; NOT NULL in SMAC |
| 3 | `role_display_name`, `name` | text | `name` | text | `LEFT(COALESCE(display_name, name, 'UNKNOWN'), 255)` | Prefers `role_display_name`; NOT NULL in SMAC |
| 4 | `role_display_name`, `name` | text | `description` | text | `TRIM(COALESCE(display_name, name))` when non-empty; else `NULL` | Uses display name as description |
| 5 | `department_id` (via `vessel_fdl`), `display_name` | integer, text | `fdl_department_id` | uuid | Map via `role_department_mapping` + `fdl_departments_id_mapping`; insurance name override | Lookup: `migration.table_mappings` where `target_table = 'fdl_departments'` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC has no status/deleted_at columns |
| 11 | `create_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(create_at, NOW())` with infinity/invalid date fallback to `NOW()` | SAC column is `create_at` (not `created_at`) |
| 12 | `update_at`, `create_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(update_at, create_at, NOW())` with infinity/invalid date handling | SAC column is `update_at` (not `updated_at`) |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 14 | `role_display_name` | text | `tags` | text[] | Array: lowercase snake, UPPER_SNAKE, UPPERCASE variants of display_name | Post-migration UPDATE appends `group_head` for Group Head roles |
| 15 | — | — | `scope` | integer | Hardcoded `2` | Vessel-level scope; not in SAC source |

**SMAC columns not migrated:** `deleted_at`, `parent_id`, `archived_at`, `level` — no source equivalent in SAC `vessel_fdl_roles`.

**SAC columns not migrated:** `audit_info` (jsonb) — SAC audit JSONB not mapped; SMAC uses `build_audit_info()` with system user defaults.

**Additional seed records (not from SAC column mapping):** Fleet-level roles inserted from `fleet_level_role_mapping` temp table matched to `fdl_departments` — see migration script INSERT blocks 2–10.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fdl_departments`

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
