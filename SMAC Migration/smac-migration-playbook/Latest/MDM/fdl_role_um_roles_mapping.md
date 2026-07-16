# Table Mapping: vessel_fdl → fdl_role_um_roles

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_fdl
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_role_um_roles
- **Source Script**: `04-migration-scripts/master/fdl_role_um_roles_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_fdl`
- **New Path**: `smac_master_migration.vessel.fdl_role_um_roles`

## Business Key

- **Composite Key**: (`fdl_role_id`, `um_role_id`)
- **Source (orchestration)**: Fdl Role Um Roles (`vessel_fdl_role_um_roles` → `fdl_role_um_roles`)

## Migration Notes

- Junction table mapping FDL roles to User Management (UM) roles — no direct SAC source table
- Primary source: distinct `(user_id, fdl_role_id)` from `vessel.fdl_role_assignments`
- `um_role_id` resolved via `user_roles_mapping` dblink to `smac_idp_dev.user_roles` joined with `user_profiles`
- `id` uses `migration.resolve_target_id()` with composite `source_id = fdl_role_id || '|' || um_role_id`; `p_target_id = NULL`
- Second staging INSERT: FDL roles without assignments get default `um_role_id` from first staged mapping
- `status` hardcoded Active via `:'STATUS_ACTIVE'::integer`; `deleted_at` set to NULL
- Requires `fdl_role_assignments` migrated first; requires `smac_idp_dev` dblink for UM role lookup
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_role_um_roles` before insert (full table reload).
- Orchestration dependencies: `fdl_roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `user_roles_mapping` | FK lookup | `ur_data.user_id`, `um_role_id` | - | `smac_idp_dev` |
| `valid_um_roles` | Post-migration FK validation | `id` | - | `smac_idp_dev` |

### `user_roles_mapping`

- **Output columns**: ur_data.user_id, um_role_id
- **dblink connection**: `smac_idp_dev`

```sql
CREATE TEMP TABLE user_roles_mapping AS
SELECT
    ur_data.user_id,
    ur_data.role_id AS um_role_id
FROM dblink('smac_idp_dev',
    'SELECT uf.id, ur.role_id FROM public.user_roles ur JOIN public.user_profiles uf ON ur.user_id = uf.id WHERE uf.user_id IS NOT NULL AND ur.role_id IS NOT NULL'
) AS ur_data(
    user_id uuid,
    role_id uuid
);
```

### `valid_um_roles`

- **Purpose**: Validate migrated `um_role_id` values against IDP roles (post-insert check)
- **Output columns**: id
- **dblink connection**: `smac_idp_dev`

```sql
CREATE TEMP TABLE valid_um_roles AS
SELECT id FROM dblink('smac_idp_dev', 'SELECT id FROM public.roles WHERE id IS NOT NULL') AS r(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `fdl_role_id`, `um_role_id` (derived) | uuid, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `fdl_role_id \|\| '\|' \|\| um_role_id`; `p_target_id = NULL` | Composite junction key; idempotent via `id_mappings` |
| 2 | `fdl_role_assignments.fdl_role_id` | uuid | `fdl_role_id` | uuid | Direct from staged `fdl_role_assignments` | FK to `vessel.fdl_roles` |
| 3 | `user_roles.role_id` (via dblink) | uuid | `um_role_id` | uuid | Map via `user_roles_mapping` — join `fdl_role_assignments.user_id` to `smac_idp_dev.user_roles` | Lookup via dblink to `smac_idp_dev`; default used for unassigned roles |
| 4 | — | — | `is_default` | boolean | Hardcoded `false` | Not in SAC source |
| 5 | — | — | `priority` | integer | `NULL` | Not in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | `fdl_role_assignments.created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(MIN(created_at), NOW())` from assignments | Aggregated from parent assignments |
| 10 | `fdl_role_assignments.updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(MAX(updated_at), created_at, NOW())` | Aggregated from parent assignments |
| 11 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not populated |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by; staging includes `legacy_user_count` | Standardized SMAC audit structure in final INSERT |
| 14 | — | — | `level` | numeric | `NULL` | Not in SAC source |
| 15 | — | — | `tags` | text[] | `NULL` | Not populated |
| 16 | — | — | `status` | integer | `:'STATUS_ACTIVE'::integer` from `constants.sql` | Hardcoded Active; not from SAC |
| 17 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 18 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SMAC columns not migrated:** None — all target columns populated from derived data or defaults.

**SAC columns not migrated:** SAC `vessel_fdl` has no `um_role_id` column — relationship derived entirely from `fdl_role_assignments` + `smac_idp_dev.user_roles`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fdl_roles`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. User Roles ID Mapping
**Output columns**: `ur_data.user_id, um_role_id`
**dblink**: `smac_idp_dev`

```sql
CREATE TEMP TABLE user_roles_mapping AS
SELECT
    ur_data.user_id,
    ur_data.role_id AS um_role_id
FROM dblink('smac_idp_dev',
    'SELECT uf.id, ur.role_id FROM public.user_roles ur JOIN public.user_profiles uf ON ur.user_id = uf.id WHERE uf.user_id IS NOT NULL AND ur.role_id IS NOT NULL'
) AS ur_data(
    user_id uuid,
    role_id uuid
);
```

Full migration context: `04-migration-scripts/master/fdl_role_um_roles_migration.sql`

## Validation

- Run `05-validation/master/fdl_role_um_roles_validation.sql` if available
- Run `06-rollback/master/fdl_role_um_roles_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
