# Table Mapping: vessel_pool_mappings → vessel_pool_mappings

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_pool_mappings
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_pool_mappings
- **Source Script**: `04-migration-scripts/master/vessel_pool_mappings_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_pool_mappings`
- **New Path**: `smac_master_migration.vessel.vessel_pool_mappings`

## Business Key

- **Composite Key**: (`vessel_id`, `vessel_pool_id`)
- **Source (orchestration)**: Vessel Pool Mappings (`vessel_pool_mappings` → `vessel_pool_mappings`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `vessel_id` and `vessel_pool_id` via `migration.table_mappings`
- `VesselId1` duplicate of `vessel_id`
- `status` Case 2/boolean: `deleted_at` takes precedence; `status` boolean mapped to int
- Migrate ALL records including deleted
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_pool_mappings` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_pools`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | Check for duplicate UUIDs in source table | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_pool_id_mapping` | Chec | `legacy_pool_id`, `new_pool_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_vessel_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `vessel_pool_id_mapping`

- **Purpose**: Chec
- **Output columns**: legacy_pool_id, new_pool_id
- **migration.table_mappings**: target_table=vessel_pools

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT
    source_id::uuid AS legacy_pool_id,
    target_id AS new_pool_id
FROM migration.table_mappings
WHERE target_table = 'vessel_pools'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `vessel_id` | uuid | `vessel_id` | uuid | Map via `vessel_id_mapping` → vessels | FK lookup |
| 3 | `vessel_pool_id` | uuid | `vessel_pool_id` | uuid | Map via `vessel_pool_id_mapping` → vessel_pools | FK lookup |
| 4 | `effective_from` | timestamp without time zone | `effective_from` | timestamp without time zone | Direct copy | Direct copy |
| 5 | `effective_until` | timestamp without time zone | `effective_until` | timestamp without time zone | Direct copy | Direct copy |
| 6 | `vessel_id` | uuid | `VesselId1` | uuid | Duplicate of `vessel_id` | Legacy column name preserved |
| 7 | `status, deleted_at` | boolean, timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else map boolean status | Case 2 variant |
| 8 | `created_by_id, updated_by_id, deleted_by_id` | uuid | `audit_info` | jsonb | `migration.build_audit_info()` with user IDs | Standardized SMAC structure |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 12 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 13 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 15 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 16 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |
| 17 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |
| 18 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 19 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |

**SAC columns not migrated:** None from dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel_pools`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_vessel_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Vessel Pool ID Mapping
**Purpose**: Chec
**Output columns**: `legacy_pool_id, new_pool_id`
**migration.table_mappings**: `target_table='vessel_pools'`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT
    source_id::uuid AS legacy_pool_id,
    target_id AS new_pool_id
FROM migration.table_mappings
WHERE target_table = 'vessel_pools'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_pool_mappings_migration.sql`

## Validation

- Run `05-validation/master/vessel_pool_mappings_validation.sql` if available
- Run `06-rollback/master/vessel_pool_mappings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
