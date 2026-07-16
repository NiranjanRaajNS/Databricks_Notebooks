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

- Split migration into two sections:
- Preserves legacy identifier (UUID) as new id for vessel assignments
- Maps role_id → fdl_role_id via migration.table_mappings (fdl_roles)
- Maps vessel_id → vessel_id via migration.table_mappings (vessels) for vessel assignments only
- Maps fleet_id → fleet_id via migration.table_mappings (fleets) if exists
- Maps cluster_id → cluster_id via migration.table_mappings (clusters) for cluster assignments
- Converts status (varchar) → status (integer): Active=0, Draft=1, Inactive=2, Deleted=3
- Maps approved_at → workflow_status: if approved_at IS NOT NULL then 2 (Approved), else 0 (Draft)
- all_ranks_applicable default changes from false to true
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- is_current: false if status='Inactive' OR handover_date IS NOT NULL, else true
- Migrates vessel_fdl preserving identifier (UUID) as new id. Maps role_id → fdl_role_id via migration.table_mappings (fdl_roles). Maps vessel_id → vessel_id via migration.table_mappings (vessels). Maps fleet_id → fleet_id via migration.table_mappings (fleets) if exists. Maps cluster_id → cluster_id via migration.table_mappings (clusters) if exists. Converts status (varchar) → status (integer): Active=0, Draft=1, Inactive=2, Deleted=3. Maps approved_at → workflow_status: if approved_at IS NOT NULL then 2 (Approved), else 0 (Draft). Includes all rows (including deleted rows with deleted_at IS NOT NULL).

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
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_fdl'::VARCHAR(100), sca.legacy_identifier::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | fleet_id | - | sca.new_fleet_id AS fleet_id | sca.new_fleet_id |
| 3 | derived | - | cluster_id | - | sca.new_cluster_id AS cluster_id | sca.new_cluster_id |
| 4 | derived | - | vessel_id | - | NULL AS vessel_id | NULL |
| 5 | derived | - | vessel_revision_id | - | NULL AS vessel_revision_id | NULL |
| 6 | derived | - | fdl_role_id | - | sca.new_fdl_role_id AS fdl_role_id | sca.new_fdl_role_id |
| 7 | derived | - | user_id | - | sca.legacy_user_id AS user_id | sca.legacy_user_id |
| 8 | derived | - | backup_user_id | - | sca.legacy_backup_user_id AS backup_user_id | sca.legacy_backup_user_id |
| 9 | derived | - | level | - | COALESCE(sca.legacy_role_user_order::numeric, 0) AS level | COALESCE(sca.legacy_role_user_order::numeric, 0) |
| 10 | derived | - | is_primary | - | COALESCE(sca.legacy_is_primary, false) AS is_primary | COALESCE(sca.legacy_is_primary, false) |
| 11 | derived | - | all_ranks_applicable | - | CASE WHEN sca.legacy_seafarer_rank_ids IS NOT NULL THEN false ELSE COALESCE(sca.legacy_all_ranks_applicable, true) END AS all_ranks_applicable | CASE WHEN sca.legacy_seafarer_rank_ids IS NOT NULL THEN false ELSE COALESCE(sca.legacy_all_ranks_applicable, true) END |
| 12 | derived | - | effective_from | - | sca.legacy_effective_ | sca.legacy_effective_ |
| 13 | - | - | effective_to | - | See source script | See source script |
| 14 | - | - | handover | - | See source script | See source script |
| 15 | - | - | tenant_id | - | See source script | See source script |
| 16 | - | - | parent_id | - | See source script | See source script |
| 17 | - | - | version | - | See source script | See source script |
| 18 | - | - | created_at | - | See source script | See source script |
| 19 | - | - | updated_at | - | See source script | See source script |
| 20 | - | - | deleted_at | - | See source script | See source script |
| 21 | - | - | archived_at | - | See source script | See source script |
| 22 | - | - | audit_info | - | See source script | See source script |
| 23 | - | - | scope | - | See source script | See source script |
| 24 | - | - | tags | - | See source script | See source script |
| 25 | - | - | status | - | See source script | See source script |
| 26 | - | - | workflow_status | - | See source script | See source script |
| 27 | - | - | defined_by | - | See source script | See source script |
| 28 | - | - | is_current | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.fdl_roles`
- `vessel.vessels`

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
