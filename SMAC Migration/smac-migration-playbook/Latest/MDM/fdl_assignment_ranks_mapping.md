# Table Mapping: fdl_assignment_ranks → fdl_assignment_ranks

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_fdl (`seafarer_rank_ids` array unnest)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_assignment_ranks
- **Source Script**: `04-migration-scripts/master/fdl_assignment_ranks_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_fdl.seafarer_rank_ids`
- **New Path**: `smac_master_migration.vessel.fdl_assignment_ranks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## Migration Notes

- Junction table: unnests `vessel_fdl.seafarer_rank_ids` array — one row per rank per assignment
- `id` uses `migration.resolve_target_id()` with composite `source_id = identifier || '|' || seafarer_rank_id`; `p_target_id = NULL`
- `assignment_id` resolved via `migration.table_mappings` join on `vessel_fdl.identifier` → `fdl_role_assignments.id`
- `seafarer_rank_id` mapped via `seafarer_rank_id_mapping` (SAC rank UUID → SMAC `ranks.id`)
- `level` inherited from parent `fdl_role_assignments.level`
- `status` derived from `deleted_at` + `status` varchar (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Filter: rows with valid assignment mapping and rank mapping only
- Requires `fdl_role_assignments` and `ranks` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_assignment_ranks` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_rank_source_id`, `new_rank_id` | `synergy_master.?.ranks` → `?.?.ranks` | - |
| `ranks_legacy_data` | Legacy rank id/identifier pairs | `legacy_rank_id`, `legacy_rank_identifier` | - | `synergy_master` |
| `seafarer_rank_id_mapping` | FK lookup | `legacy_seafarer_rank_identifier`, `new_seafarer_rank_id` | - | - |

### `ranks_id_mapping`

- **Output columns**: legacy_rank_source_id, new_rank_id
- **migration.table_mappings**: source_db=synergy_master, source_table=ranks, target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_source_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND source_table = 'ranks'
  AND source_db = 'synergy_master'
  AND target_db = current_database();
```

### `ranks_legacy_data`

- **Purpose**: Load legacy rank id and identifier UUID pairs for seafarer rank resolution
- **Output columns**: legacy_rank_id, legacy_rank_identifier
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE ranks_legacy_data AS
SELECT
    r.id AS legacy_rank_id,
    r.identifier AS legacy_rank_identifier
FROM dblink('synergy_master',
    'SELECT id, identifier
     FROM public.ranks
     WHERE identifier IS NOT NULL'
) AS r(
    id bigint,
    identifier uuid
);
```

### `seafarer_rank_id_mapping`

- **Output columns**: legacy_seafarer_rank_identifier, new_seafarer_rank_id

```sql
CREATE TEMP TABLE seafarer_rank_id_mapping AS
SELECT DISTINCT
    rld.legacy_rank_identifier::text AS legacy_seafarer_rank_identifier,
    COALESCE(

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_identifier::text),

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_id::text),
        NULL
    ) AS new_seafarer_rank_id
FROM ranks_legacy_data rld;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `seafarer_rank_ids` | uuid, uuid[] | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier \|\| '\|' \|\| seafarer_rank_id`; `p_target_id = NULL` | Composite junction key; idempotent via `id_mappings` |
| 2 | `identifier` | uuid | `assignment_id` | uuid | Join `fdl_role_assignments` via `migration.table_mappings` on `vessel_fdl.identifier` | FK to parent assignment; NOT NULL in SMAC |
| 3 | `seafarer_rank_ids` (unnest) | uuid | `seafarer_rank_id` | uuid | Map via `seafarer_rank_id_mapping` (SAC rank identifier → SMAC `ranks.id`) | Lookup through `migration.table_mappings` where `target_table = 'ranks'` |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 5 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 7 | `create_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(create_at, NOW())` | SAC column is `create_at` (not `created_at`) |
| 8 | `update_at`, `create_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(update_at, create_at, NOW())` | SAC column is `update_at` (not `updated_at`) |
| 9 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 10 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 11 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; `legacy_id` handled by `id_mappings` |
| 12 | — | — | `tags` | text[] | `NULL` | Not populated in migration |
| 13 | `role_user_order` (via parent) | integer | `level` | numeric | `COALESCE(fdl_role_assignments.level, 0)` | Inherited from parent assignment's `level` |
| 14 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 15 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 16 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SMAC columns not migrated:** None — all target columns populated from SAC `vessel_fdl` or defaults.

**SAC columns not migrated:** `role_id`, `vessel_id`, `user_id`, `fleet_id`, `cluster_id`, and other `vessel_fdl` columns — handled by `fdl_role_assignments` migration; only `seafarer_rank_ids` array elements used here.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fdl_role_assignments`
- `vessel.fdl_role_assignments`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_rank_source_id, new_rank_id`
**migration.table_mappings**: `ranks` → `ranks` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text AS legacy_rank_source_id,
    target_id AS new_rank_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND source_table = 'ranks'
  AND source_db = 'synergy_master'
  AND target_db = current_database();
```

### 2. Seafarer Rank ID Mapping
**Output columns**: `legacy_seafarer_rank_identifier, new_seafarer_rank_id`

```sql
CREATE TEMP TABLE seafarer_rank_id_mapping AS
SELECT DISTINCT
    rld.legacy_rank_identifier::text AS legacy_seafarer_rank_identifier,
    COALESCE(

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_identifier::text),

        (SELECT rim.new_rank_id FROM ranks_id_mapping rim WHERE rim.legacy_rank_source_id = rld.legacy_rank_id::text),
        NULL
    ) AS new_seafarer_rank_id
FROM ranks_legacy_data rld;
```

Full migration context: `04-migration-scripts/master/fdl_assignment_ranks_migration.sql`

## Validation

- Run `05-validation/master/fdl_assignment_ranks_validation.sql` if available
- Run `06-rollback/master/fdl_assignment_ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
