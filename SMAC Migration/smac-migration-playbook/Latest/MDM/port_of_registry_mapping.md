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

- Source: `synergy_vessel.public.ports` WHERE `port_of_registry = true` → `vessel.port_of_registry`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- Depends on `ports`, `flags`, and `countries` migrated first
- `flag_id_mapping`: legacy flags.country → countries → flags
- `port_id_mapping`: self-reference via ports migration mappings
- `DISTINCT ON (identifier)` deduplication
- `status` Case 1 from `deleted_at`

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
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` |  |
| 2 | `name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(COALESCE(TRIM(name), 'UNKNOWN'), identifier::text)` |  |
| 3 | `name` | text | `name` | text | `COALESCE(NULLIF(TRIM(name), ''), 'UNKNOWN')` |  |
| 4 | `id` | bigint | `port_id` | uuid | Map via `port_id_mapping` from ports table_mappings; fallback zero-UUID | Self FK |
| 5 | `country_id` | bigint | `flag_id` | uuid | Map via `flag_id_mapping` through countries; fallback zero-UUID | FK lookup |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 10 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 11 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 13 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 14 | `created_by_id, updated_by_id` | varchar | `audit_info` | jsonb | `migration.build_audit_info(created_by_id, NULL, updated_by_id, ...)` |  |

**SAC columns not migrated:** `created_by_name`, `updated_by_name`, `port_of_registry` filter flag.

**SMAC columns not migrated:** `deleted_at`, `description`, `tags`.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `flags`
- `ports`

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
