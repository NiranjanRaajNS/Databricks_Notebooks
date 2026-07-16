# Table Mapping: ports (where port_of_registry = true) → port_of_registry

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ports (where port_of_registry = true)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: port_of_registry
- **Source Script**: `04-migration-scripts/master/port_of_registry_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ports (where port_of_registry = true)`
- **New Path**: `smac_master_migration.vessel.port_of_registry`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Port Of Registry (`ports` → `port_of_registry`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.port_of_registry` before insert (full table reload).
- Orchestration dependencies: `flags`, `ports`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `flag_id_mapping` | FK lookup | `country_id`, `flag_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `port_id_mapping` | FK lookup | `legacy_port_id`, `new_port_id` | `migration.table_mappings` (see SQL) | - |

### `flag_id_mapping`

- **Output columns**: country_id, flag_id
- **migration.table_mappings**: target_table=countries
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT ON (flag_country_map.target_id)
    flag_country_map.target_id AS country_id,
    flag_map.target_id AS flag_id
FROM dblink('synergy_vessel',
    'SELECT id, country FROM public.flags'
) AS legacy_flags(id bigint, country bigint)
JOIN migration.table_mappings flag_country_map
    ON flag_country_map.source_id = legacy_flags.country::text
    AND flag_country_map.target_table = 'countries'
    AND flag_country_map.target_db = current_database()
JOIN migration.table_mappings flag_map
    ON flag_map.source_id = legacy_flags.id::text
    AND flag_map.target_table = 'flags'
    AND flag_map.target_db = current_database()
ORDER BY flag_country_map.target_id, flag_map.target_id;
```

### `port_id_mapping`

- **Output columns**: legacy_port_id, new_port_id
- **migration.table_mappings**: target_table=ports

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_port_id,
    target_id AS new_port_id
FROM migration.table_mappings
WHERE target_table = 'ports'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.identifier) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'ports'::VARCHAR(100), legacy_data.identifier::text, cu... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | COALESCE( generate_meaningful_code(COALESCE(NULLIF(TRIM(legacy_data.name), ''), 'UNKNOWN'), legacy_data.identifier::text), 'UNKNOWN' ) |
| 3 | name | - | name | - | COALESCE(NULLIF(TRIM(legacy_data.name), ''), 'UNKNOWN') AS name | COALESCE(NULLIF(TRIM(legacy_data.name), ''), 'UNKNOWN') |
| 4 | derived | - | port_id | - | COALESCE(pm.new_port_id, '00000000-0000-0000-0000-000000000000'::uuid) AS port_id | COALESCE(pm.new_port_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | flag_id | - | COALESCE(fm.flag_id, '00000000-0000-0000-0000-000000000000'::uuid) AS flag_id | COALESCE(fm.flag_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 14 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, NULL::v... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Flag ID Mapping
**Output columns**: `country_id, flag_id`
**migration.table_mappings**: `target_table='countries'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT ON (flag_country_map.target_id)
    flag_country_map.target_id AS country_id,
    flag_map.target_id AS flag_id
FROM dblink('synergy_vessel',
    'SELECT id, country FROM public.flags'
) AS legacy_flags(id bigint, country bigint)
JOIN migration.table_mappings flag_country_map
    ON flag_country_map.source_id = legacy_flags.country::text
    AND flag_country_map.target_table = 'countries'
    AND flag_country_map.target_db = current_database()
JOIN migration.table_mappings flag_map
    ON flag_map.source_id = legacy_flags.id::text
    AND flag_map.target_table = 'flags'
    AND flag_map.target_db = current_database()
ORDER BY flag_country_map.target_id, flag_map.target_id;
```

### 2. Port ID Mapping
**Output columns**: `legacy_port_id, new_port_id`
**migration.table_mappings**: `target_table='ports'`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT
    source_id::bigint AS legacy_port_id,
    target_id AS new_port_id
FROM migration.table_mappings
WHERE target_table = 'ports'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/port_of_registry_migration.sql`

## Validation

- Run `05-validation/master/port_of_registry_validation.sql` if available
- Run `06-rollback/master/port_of_registry_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
