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

- Migrates seafarer_temperature_logs. Uses migration.resolve_target_id() for idempotent UUID generation. Maps seafarer_id via seafarers mapping. Casts temperature from integer to numeric(5,2). Maps status based on deleted_at (Deleted if deleted_at IS NOT NULL, else Active).

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
| 1 | derived | - | id | - | id_map.new_id AS id | id_map.new_id |
| 2 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 3 | temperature | - | temperature | - | CASE WHEN legacy_data.temperature IS NULL THEN 0.0::numeric(4,2) WHEN legacy_data.temperature > 99 THEN 99.99::numeric(4,2) WHEN legacy_data.temperature < -99 THEN -99.99::numer... | CASE WHEN legacy_data.temperature IS NULL THEN 0.0::numeric(4,2) WHEN legacy_data.temperature > 99 THEN 99.99::numeric(4,2) WHEN legacy_data.temperature < -99 THEN -99.99::numer... |
| 4 | date | - | log_date | - | legacy_data.date AS log_date | legacy_data.date |
| 5 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 11 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id::text) <> '' AND TRIM(legacy_data.created_by_id::text) ~ '^[0-9]+$... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
