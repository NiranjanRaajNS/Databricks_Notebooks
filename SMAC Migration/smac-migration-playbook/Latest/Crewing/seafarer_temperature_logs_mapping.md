# Table Mapping: seafarer_temperature_logs → seafarer_temperature_logs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_temperature_logs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_temperature_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_temperature_logs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_temperature_logs`
- **New Path**: `smac_crewing_migration.public.seafarer_temperature_logs`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Temperature Logs (`seafarer_temperature_logs` → `seafarer_temperature_logs`)

## Migration Notes

- `id` pre-populated via `temperature_logs_id_mapping` + `migration.store_table_mappings()` before INSERT
- `seafarer_id` mapped via `seafarers` table_mappings — INNER JOIN excludes unmapped seafarers
- `temperature` (integer) cast to `numeric(4,2)` with clamping to ±99.99; NULL → `0.0`
- `status` derived from `deleted_at` (`'Deleted'` / `'Active'`)
- Integer `created_by_id`/`updated_by_id` mapped to `SYSTEM_USER_ID` when not valid UUID; names in `audit_info.notes`
- Pre-migration `TRUNCATE`; all records including deleted migrated

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_temperature_logs` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `temperature_logs_id_mapping` | FK lookup | `legacy_id`, `new_id` | `synergy_seafarer.public.seafarer_temperature_logs` → `?.public.seafarer_temperature_logs` | `synergy_seafarer` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `temperature_logs_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=seafarer_temperature_logs, target_schema=public, target_table=seafarer_temperature_logs
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE temperature_logs_id_mapping AS
SELECT DISTINCT
    legacy_data.id AS legacy_id,
    COALESCE(tm.target_id, gen_random_uuid()) AS new_id
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT id FROM public.seafarer_temperature_logs'
) AS legacy_data(id bigint)
LEFT JOIN migration.table_mappings tm ON
    tm.source_db = 'synergy_seafarer'
    AND tm.source_schema = 'public'
    AND tm.source_table = 'seafarer_temperature_logs'
    AND tm.source_id = legacy_data.id::text
    AND tm.target_db = current_database()
    AND tm.target_schema = 'public'
    AND tm.target_table = 'seafarer_temperature_logs';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | Pre-populated mapping / `gen_random_uuid()` | Idempotent via `store_table_mappings` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping` (INNER JOIN) | Required; unmapped excluded |
| 3 | `temperature` | integer | `temperature` | numeric(4,2) | Cast + clamp to ±99.99; NULL → `0.0` | |
| 4 | `date` | timestamp without time zone | `log_date` | timestamp without time zone | Direct copy | |
| 5 | `deleted_at` | timestamp without time zone | `status` | text | `'Deleted'` when `deleted_at IS NOT NULL`; else `'Active'` | |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 9 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 11 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — integer IDs → `SYSTEM_USER_ID`; names in `notes` | |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** None — all dblink columns are used.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Temperature Logs ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `seafarer_temperature_logs` → `seafarer_temperature_logs` (source_db=`synergy_seafarer`)
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE temperature_logs_id_mapping AS
SELECT DISTINCT
    legacy_data.id AS legacy_id,
    COALESCE(tm.target_id, gen_random_uuid()) AS new_id
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT id FROM public.seafarer_temperature_logs'
) AS legacy_data(id bigint)
LEFT JOIN migration.table_mappings tm ON
    tm.source_db = 'synergy_seafarer'
    AND tm.source_schema = 'public'
    AND tm.source_table = 'seafarer_temperature_logs'
    AND tm.source_id = legacy_data.id::text
    AND tm.target_db = current_database()
    AND tm.target_schema = 'public'
    AND tm.target_table = 'seafarer_temperature_logs';
```

Full migration context: `04-migration-scripts/crewing/seafarer_temperature_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_temperature_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_temperature_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
