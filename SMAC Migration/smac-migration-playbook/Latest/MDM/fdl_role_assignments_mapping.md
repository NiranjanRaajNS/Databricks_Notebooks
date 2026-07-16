# Table Mapping: vessel_fdl → fdl_role_assignments

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_fdl
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_role_assignments
- **Source Script**: `04-migration-scripts/master/fdl_role_assignments_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_fdl`
- **New Path**: `smac_master_migration.vessel.fdl_role_assignments`

## Business Key

- **Composite Key**: (`fdl_role_id`, `vessel_id`, `user_id`)
- **Source (orchestration)**: Vessel Fdl (`vessel_fdl` → `fdl_role_assignments`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Script contains 4 INSERT blocks: (1) cluster assignments, (2) vessel assignments, (3–4) fleet PIC from `fleet_master`
- Cluster assignments (`cluster_id IS NOT NULL`): `scope = 2`, `vessel_id`/`vessel_revision_id` = NULL
- Vessel assignments (`cluster_id IS NULL`): `scope = 3`, maps `vessel_id` via `vessel_details` → `vessels` lookup
- `fdl_role_id` mapped via `fdl_roles_id_mapping`; `fleet_id`/`cluster_id` via respective `table_mappings`
- `vessel_revision_id` mapped via `vessel_revisions_id_mapping` (vessel assignments only)
- `all_ranks_applicable`: `false` when `seafarer_rank_ids IS NOT NULL`; else `COALESCE(all_ranks_applicable, true)`
- `status` derived from `deleted_at` + `status` varchar (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- `is_current` derived from effective dates, status, handover, and ROW_NUMBER per partition
- `approved_at` passed to `audit_info` via `build_audit_info()`; `workflow_status` uses constant default
- Includes all rows (including deleted); requires `fdl_roles`, `vessels`, `fleets`, `clusters` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Cluster assignments use composite source_id (cluster_id + role_id) for idempotent mapping
- Includes all rows (including deleted rows with deleted_at IS NOT NULL)
- Script performs `TRUNCATE TABLE vessel.fdl_role_assignments` before insert (full table reload).
- Orchestration dependencies: `fdl_roles`, `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `fdl_roles_id_mapping` | FK lookup | `legacy_role_id`, `new_fdl_role_id` | `migration.table_mappings` (see SQL) | - |
| `vessels_id_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `fleets_id_mapping` | FK lookup | `legacy_fleet_id`, `new_fleet_id` | `migration.table_mappings` (see SQL) | - |
| `clusters_id_mapping` | FK lookup | `legacy_cluster_id`, `new_cluster_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_revisions_id_mapping` | FK lookup | `legacy_vessel_details_id`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | - |
| `fleet_pic_mapping` | FK lookup | `new_fleet_id`, `f.fdl_department_id`, `legacy_fleet_id`, `fm.manager_user_id`, `fm.group_head_user_id`, `fleet_status`, `fleet_created_at`, `fleet_updated_at`, `fleet_handover`, `fleet_audit_info`, `manager_role_id`, `group_head_role_id` | - | `synergy_vessel` |

### `fdl_roles_id_mapping`

- **Output columns**: legacy_role_id, new_fdl_role_id
- **migration.table_mappings**: target_table=fdl_roles

```sql
CREATE TEMP TABLE fdl_roles_id_mapping AS
SELECT
    source_id::uuid AS legacy_role_id,
    target_id AS new_fdl_role_id
FROM migration.table_mappings
WHERE target_table = 'fdl_roles'
  AND target_db = current_database();
```

### `vessels_id_mapping`

- **Output columns**: legacy_vessel_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `fleets_id_mapping`

- **Output columns**: legacy_fleet_id, new_fleet_id
- **migration.table_mappings**: target_table=fleets

```sql
CREATE TEMP TABLE fleets_id_mapping AS
SELECT
    source_id::text AS legacy_fleet_id,
    target_id AS new_fleet_id
FROM migration.table_mappings
WHERE target_table = 'fleets'
  AND target_db = current_database();
```

### `clusters_id_mapping`

- **Output columns**: legacy_cluster_id, new_cluster_id
- **migration.table_mappings**: target_table=clusters

```sql
CREATE TEMP TABLE clusters_id_mapping AS
SELECT
    source_id::uuid AS legacy_cluster_id,
    target_id AS new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### `vessel_revisions_id_mapping`

- **Output columns**: legacy_vessel_details_id, new_vessel_revision_id
- **migration.table_mappings**: target_table=vessel_revisions

```sql
CREATE TEMP TABLE vessel_revisions_id_mapping AS
SELECT
    source_id::text AS legacy_vessel_details_id,
    target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings
WHERE target_table = 'vessel_revisions'
  AND target_db = current_database();
```

### `fleet_pic_mapping`

- **Output columns**: new_fleet_id, f.fdl_department_id, legacy_fleet_id, fm.manager_user_id, fm.group_head_user_id, fleet_status, fleet_created_at, fleet_updated_at, fleet_handover, fleet_audit_info, manager_role_id, group_head_role_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE fleet_pic_mapping AS
SELECT
    f.id AS new_fleet_id,
    f.fdl_department_id,
    fm.id AS legacy_fleet_id,
    fm.manager_user_id,
    fm.group_head_user_id,
    fm.status AS fleet_status,
    fm.created_at AS fleet_created_at,
    fm.updated_at AS fleet_updated_at,
    NULL::timestamp AS fleet_handover,
    fm.audit_info AS fleet_audit_info,

    (
        SELECT fr.id
        FROM vessel.fdl_roles fr
        WHERE fr.fdl_department_id = f.fdl_department_id
          AND (
              UPPER(fr.code) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%MANAGER%'
          )
          AND NOT (UPPER(fr.name) LIKE '%PROCUREMENT%' OR UPPER(fr.code) LIKE '%PROCUREMENT%')
          AND fr.deleted_at IS NULL
        ORDER BY
            CASE WHEN UPPER(fr.name) LIKE '%MANAGER%' THEN 1 ELSE 2 END,
            fr.name
        LIMIT 1
    ) AS manager_role_id,

    (
        SELECT fr.id
        FROM vessel.fdl_roles fr
        WHERE fr.fdl_department_id = f.fdl_department_id
          AND (
              UPPER(fr.code) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%GROUP%H...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `fleet_id` | uuid | `fleet_id` | uuid | Map via `fleets_id_mapping` | Lookup: `migration.table_mappings` where `target_table = 'fleets'` |
| 3 | `cluster_id` | uuid | `cluster_id` | uuid | Map via `clusters_id_mapping`; NULL for vessel assignments | Cluster assignments only; lookup `target_table = 'clusters'` |
| 4 | `vessel_id` | uuid | `vessel_id` | uuid | Map via `vessel_details` → `vessels_id_mapping`; NULL for cluster assignments | Vessel assignments only; `vessel_id` references `vessel_details.identifier` |
| 5 | `vessel_id` (via `vessel_details`) | uuid, bigint | `vessel_revision_id` | uuid | Map via `vessel_revisions_id_mapping`; NULL for cluster assignments | Vessel assignments only; lookup `target_table = 'vessel_revisions'` |
| 6 | `role_id` | uuid | `fdl_role_id` | uuid | Map via `fdl_roles_id_mapping` | Lookup: `migration.table_mappings` where `target_table = 'fdl_roles'` |
| 7 | `user_id` | uuid | `user_id` | uuid | Direct copy | UUID preserved from SAC |
| 8 | `backup_user_id` | uuid | `backup_user_id` | uuid | Direct copy | UUID preserved from SAC |
| 9 | `role_user_order` | integer | `level` | numeric | `COALESCE(role_user_order::numeric, 0)` | SAC display order maps to SMAC `level` |
| 10 | `IsPrimary` | boolean | `is_primary` | boolean | `COALESCE("IsPrimary", false)` | SAC column name is case-sensitive `"IsPrimary"` |
| 11 | `all_ranks_applicable`, `seafarer_rank_ids` | boolean, uuid[] | `all_ranks_applicable` | boolean | `false` when `seafarer_rank_ids IS NOT NULL`; else `COALESCE(all_ranks_applicable, true)` | Default changed from SAC `false` to SMAC `true` when no rank list |
| 12 | `effective_from_date` | timestamp without time zone | `effective_from` | timestamp without time zone | Direct copy | Assignment effective start date |
| 13 | `handover_date` | timestamp without time zone | `effective_to` | timestamp without time zone | Direct copy from `handover_date` | End of assignment period |
| 14 | `handover_date` | timestamp without time zone | `handover` | timestamp without time zone | Direct copy | Handover timestamp preserved |
| 15 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 16 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 17 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 18 | `create_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(create_at, NOW())` | SAC column is `create_at` (not `created_at`) |
| 19 | `update_at`, `create_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(update_at, create_at, NOW())` | SAC column is `update_at` (not `updated_at`) |
| 20 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 21 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 22 | `approved_at` | timestamp without time zone | `audit_info` | jsonb | `migration.build_audit_info()` — `approved_at` passed as `p_approved_at`; `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 23 | — | — | `scope` | integer | `2` (cluster) or `3` (vessel) | Cluster scope=2; vessel scope=3; fleet PIC uses department scope |
| 24 | — | — | `tags` | text[] | `NULL` | Not populated in primary INSERT blocks |
| 25 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 26 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not derived from `approved_at` in INSERT |
| 27 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 28 | `effective_from_date`, `status`, `handover_date`, `deleted_at` | various | `is_current` | boolean | `ROW_NUMBER()` per `(fleet_id, cluster_id, fdl_role_id, vessel_revision_id)` with date/status/handover rules | Latest valid active assignment marked current |

**SMAC columns not migrated:** None in primary blocks — all target columns populated.

**SAC columns not migrated:** `user_email`, `department`, `display_order`, `department_id`, `seafarer_rank_ids` (handled by `fdl_assignment_ranks`), `audit_info` (jsonb) — not mapped to SMAC audit fields.

**Additional INSERT blocks (fleet PIC from `fleet_master`):** Manager and Group Head assignments derived from `fleet_master.manager_user_id`/`group_head_user_id` with role lookup by department — see migration script sections 3–4.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fdl_roles`
- `vessel.fdl_roles`
- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Fdl Roles ID Mapping
**Output columns**: `legacy_role_id, new_fdl_role_id`
**migration.table_mappings**: `target_table='fdl_roles'`

```sql
CREATE TEMP TABLE fdl_roles_id_mapping AS
SELECT
    source_id::uuid AS legacy_role_id,
    target_id AS new_fdl_role_id
FROM migration.table_mappings
WHERE target_table = 'fdl_roles'
  AND target_db = current_database();
```

### 2. Vessels ID Mapping
**Output columns**: `legacy_vessel_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 3. Fleets ID Mapping
**Output columns**: `legacy_fleet_id, new_fleet_id`
**migration.table_mappings**: `target_table='fleets'`

```sql
CREATE TEMP TABLE fleets_id_mapping AS
SELECT
    source_id::text AS legacy_fleet_id,
    target_id AS new_fleet_id
FROM migration.table_mappings
WHERE target_table = 'fleets'
  AND target_db = current_database();
```

### 4. Clusters ID Mapping
**Output columns**: `legacy_cluster_id, new_cluster_id`
**migration.table_mappings**: `target_table='clusters'`

```sql
CREATE TEMP TABLE clusters_id_mapping AS
SELECT
    source_id::uuid AS legacy_cluster_id,
    target_id AS new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### 5. Vessel Revisions ID Mapping
**Output columns**: `legacy_vessel_details_id, new_vessel_revision_id`
**migration.table_mappings**: `target_table='vessel_revisions'`

```sql
CREATE TEMP TABLE vessel_revisions_id_mapping AS
SELECT
    source_id::text AS legacy_vessel_details_id,
    target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings
WHERE target_table = 'vessel_revisions'
  AND target_db = current_database();
```

### 6. Fleet Pic ID Mapping
**Output columns**: `new_fleet_id, f.fdl_department_id, legacy_fleet_id, fm.manager_user_id, fm.group_head_user_id, fleet_status, fleet_created_at, fleet_updated_at, fleet_handover, fleet_audit_info, manager_role_id, group_head_role_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE fleet_pic_mapping AS
SELECT
    f.id AS new_fleet_id,
    f.fdl_department_id,
    fm.id AS legacy_fleet_id,
    fm.manager_user_id,
    fm.group_head_user_id,
    fm.status AS fleet_status,
    fm.created_at AS fleet_created_at,
    fm.updated_at AS fleet_updated_at,
    NULL::timestamp AS fleet_handover,
    fm.audit_info AS fleet_audit_info,

    (
        SELECT fr.id
        FROM vessel.fdl_roles fr
        WHERE fr.fdl_department_id = f.fdl_department_id
          AND (
              UPPER(fr.code) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%MANAGER%'
          )
          AND NOT (UPPER(fr.name) LIKE '%PROCUREMENT%' OR UPPER(fr.code) LIKE '%PROCUREMENT%')
          AND fr.deleted_at IS NULL
        ORDER BY
            CASE WHEN UPPER(fr.name) LIKE '%MANAGER%' THEN 1 ELSE 2 END,
            fr.name
        LIMIT 1
    ) AS manager_role_id,

    (
        SELECT fr.id
        FROM vessel.fdl_roles fr
        WHERE fr.fdl_department_id = f.fdl_department_id
          AND (
              UPPER(fr.code) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%PIC%'
              OR UPPER(fr.name) LIKE '%GROUP%HEAD%'
          )
         AND NOT (UPPER(fr.name) LIKE '%PROCUREMENT%' OR UPPER(fr.code) LIKE '%PROCUREMENT%')
          AND fr.deleted_at IS NULL
        ORDER BY
            CASE WHEN UPPER(fr.name) LIKE '%GROUP%HEAD%' THEN 1 ELSE 2 END,
            fr.name
        LIMIT 1
    ) AS group_head_role_id
FROM dblink('synergy_vessel',
    'SELECT id, manager_user_id, group_head_user_id, department_id, status, created_at, updated_at,
            COALESCE(audit_info, ''{}''::jsonb) as audit_info
     FROM public.fleet_master
     WHERE (manager_user_id IS NOT NULL OR group_head_user_id IS NOT NULL)'
) AS fm(
    id uuid,
    manager_user_id uuid,
    group_head_user_id uuid,
    department_id integer,
    status varchar,
    created_at timestamp,
    updated_at timestamp,
    audit_info jsonb
)
LEFT JOIN vessel.fleets f ON f.id = fm.id
WHERE f.id IS NOT NULL
  AND f.fdl_department_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/fdl_role_assignments_migration.sql`

## Validation

- Run `05-validation/master/fdl_role_assignments_validation.sql` if available
- Run `06-rollback/master/fdl_role_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
