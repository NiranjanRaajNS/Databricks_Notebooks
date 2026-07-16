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

- This is a junction table mapping FDL roles to User Management (UM) roles
- Source: fdl_role_assignments table (gets distinct user_id and fdl_role_id)
- Maps um_role_id → roles.id by finding user's role from smac_idp_dev.user_roles table
- Logic: Get distinct user_id from fdl_role_assignments, find their role_id from user_roles, map fdl_role_id → um_role_id
- fdl_role_id comes directly from fdl_role_assignments (fdl_roles table is not used)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Generates new UUIDs for junction records (standard for junction tables)
- Requires fdl_role_assignments and smac_idp_dev.user_roles to be migrated first
- Migrates fdl_role_um_roles junction table mapping FDL roles to User Management roles. Source: Existing vessel.fdl_role_um_roles in SMAC (target database) OR separate relationship table in SAC (to be discovered). Target: vessel.fdl_role_um_roles (SMAC). NOTE: vessel_fdl_roles (SAC) does NOT have um_role_id column. Generates new UUIDs for id column (junction table pattern). Maps fdl_role_id via migration.table_mappings (fdl_roles). Maps um_role_id via migration.table_mappings (roles) from smac_idp_dev database using dblink. Converts status (varchar) → status (integer): Active=0, Draft=1, Inactive=2, Deleted=3. Requires fdl_roles table to be migrated first. Requires smac_idp_dev dblink connection for roles mapping. Script primarily loads from existing SMAC data.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_role_um_roles` before insert (full table reload).
- Orchestration dependencies: `fdl_roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `user_roles_mapping` | FK lookup | `ur_data.user_id`, `um_role_id` | - | `smac_idp_dev` |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | fdl_role_id, um_role_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_fdl'::VARCHAR(100), (s.fdl_role_id::text || '|' || s.um_role_id::text)::text, curren... |
| 2 | fdl_role_id | - | fdl_role_id | - | s.fdl_role_id AS fdl_role_id | s.fdl_role_id |
| 3 | um_role_id | - | um_role_id | - | s.um_role_id AS um_role_id | s.um_role_id |
| 4 | is_default | - | is_default | - | s.is_default | s.is_default |
| 5 | priority | - | priority | - | s.priority | s.priority |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(s.updated_at, s.created_at, NOW()) AS updated_at | COALESCE(s.updated_at, s.created_at, NOW()) |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | derived | - | level | - | NULL AS level | NULL |
| 15 | derived | - | tags | - | NULL AS tags | NULL |
| 16 | derived | - | status | - | STATUS_ACTIVE | :'STATUS_ACTIVE'::integer |
| 17 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 18 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
