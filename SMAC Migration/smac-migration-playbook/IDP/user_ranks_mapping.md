# Table Mapping: user_ranks → user_ranks

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: user_ranks
- **Source Script**: `04-migration-scripts/idp/user_ranks_migration.sql`


## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `ranks_id_mapping` | DELETE FROM pu | `legacy_id`, `target_id::uuid` | `migration.table_mappings` (see SQL) | - |

### `users_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

### `ranks_id_mapping`

- **Purpose**: DELETE FROM pu
- **Output columns**: legacy_id, target_id::uuid
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | nextval(pg_get_serial_sequence('public.user_ranks', 'id')) as id | nextval(pg_get_serial_sequence('public.user_ranks', 'id')) |
| 2 | user_id | - | user_id | - | TRIM(legacy_data.user_id) as user_id | TRIM(legacy_data.user_id) |
| 3 | derived | - | rank_id | - | COALESCE(rank_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as rank_id | COALESCE(rank_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Users ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='users'`

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

### 2. Ranks ID Mapping
**Purpose**: DELETE FROM pu
**Output columns**: `legacy_id, target_id::uuid`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id::uuid
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/user_ranks_migration.sql`

## Validation

- Run `05-validation/idp/user_ranks_validation.sql` if available
- Run `06-rollback/idp/user_ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
