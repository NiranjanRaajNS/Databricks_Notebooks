# Table Mapping: sea_experience_vessel_pool → sea_experience_vessel_pool

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: sea_experience_vessel_pool
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: sea_experience_vessel_pool
- **Source Script**: `04-migration-scripts/crewing/sea_experience_vessel_pool_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.sea_experience_vessel_pool`
- **New Path**: `smac_crewing_migration.shore.sea_experience_vessel_pool`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Sea Experience Vessel Pool (`sea_experience_vessel_pool` → `sea_experience_vessel_pool`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id` (Pattern 4)
- SAC column `sefarer_uuid` (typo in source) → SMAC `seafarer_id` via `seafarer_uuid_mapping`
- `sea_experience_id` (bigint) mapped via SAC `sea_experiences.uuid` join to `seafarer_sea_experiences` mappings
- `vessel_pool_id` and `vessel_pool_mappings_id` (uuid) mapped from `smac_master_migration` `table_mappings`
- Unmapped FKs default to nil UUID (`00000000-0000-0000-0000-000000000000`) for NOT NULL constraints
- Uses `migration.build_audit_info()` from SAC `created_by_id` / `updated_by_id` / `deleted_by_id`
- Requires `seafarers`, `seafarer_sea_experiences`, `vessel_pools`, `vessel_pool_mappings` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.sea_experience_vessel_pool` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_sea_experiences`, `vessel_pools`, `vessel_pool_mappings`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `legacy_seafarer_uuid`, `new_seafarer_id` | `migration.table_mappings` (see SQL) | - |
| `sea_experience_id_mapping` | FK lookup | `legacy_sea_experience_id`, `new_sea_experience_id` | `migration.table_mappings` (see SQL) | `synergy_seafarer` |
| `vessel_pool_id_mapping` | FK lookup | `legacy_vessel_pool_id`, `new_vessel_pool_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_pool_mappings_id_mapping` | FK lookup | `legacy_vessel_pool_mappings_id`, `new_vessel_pool_mappings_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarer_uuid_mapping`

- **Output columns**: legacy_seafarer_uuid, new_seafarer_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    tm.target_id AS legacy_seafarer_uuid,
    tm.target_id AS new_seafarer_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### `sea_experience_id_mapping`

- **Output columns**: legacy_sea_experience_id, new_sea_experience_id
- **migration.table_mappings**: target_table=seafarer_sea_experiences
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE sea_experience_id_mapping AS
SELECT DISTINCT
    sac_se.id AS legacy_sea_experience_id,
    tm.target_id AS new_sea_experience_id
FROM dblink('synergy_seafarer',
    'SELECT id, COALESCE(uuid, NULL::uuid) AS uuid FROM public.sea_experiences WHERE id IS NOT NULL'
) AS sac_se(id bigint, uuid uuid)
JOIN migration.table_mappings tm ON tm.source_id::uuid = sac_se.uuid
WHERE tm.target_table = 'seafarer_sea_experiences'
  AND tm.target_db = current_database()
  AND sac_se.uuid IS NOT NULL;
```

### `vessel_pool_id_mapping`

- **Output columns**: legacy_vessel_pool_id, new_vessel_pool_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_id,
    target_id AS new_vessel_pool_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pools''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

### `vessel_pool_mappings_id_mapping`

- **Output columns**: legacy_vessel_pool_mappings_id, new_vessel_pool_mappings_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_mappings_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_mappings_id,
    target_id AS new_vessel_pool_mappings_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pool_mappings''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID; idempotent |
| 2 | `sefarer_uuid` | uuid | `seafarer_id` | uuid | Map via `seafarer_uuid_mapping`; default nil UUID if unmapped | SAC column name has typo `sefarer` |
| 3 | `sea_experience_id` | bigint | `sea_experience_id` | uuid | Map via `sea_experience_id_mapping` (SAC `sea_experiences.uuid` → SMAC); default nil UUID | LEFT JOIN |
| 4 | `vessel_pool_id` | uuid | `vessel_pool_id` | uuid | Map via `vessel_pool_id_mapping` from `smac_master_migration`; default nil UUID | LEFT JOIN |
| 5 | `vessel_pool_mappings_id` | uuid | `vessel_pool_mappings_id` | uuid | Map via `vessel_pool_mappings_id_mapping`; default nil UUID | LEFT JOIN |
| 6 | `start_date` | timestamp | `start_date` | timestamp without time zone | Direct copy | |
| 7 | `end_date` | timestamp | `end_date` | timestamp without time zone | Direct copy | |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 10 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 11 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 12 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 13 | `created_by_id`, `deleted_by_id`, `updated_by_id` | uuid | `audit_info` | jsonb | `migration.build_audit_info()` — IDs cast to varchar | - |

**SMAC columns not migrated:** `status`, `version`, `defined_by`, `workflow_status` — not in target `shore.sea_experience_vessel_pool` schema.

**SAC columns not migrated:** None beyond audit ID columns absorbed into `audit_info`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`
- `seafarer_sea_experiences`
- `seafarers`
- `vessel_pool_mappings`
- `vessel_pools`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `legacy_seafarer_uuid, new_seafarer_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    tm.target_id AS legacy_seafarer_uuid,
    tm.target_id AS new_seafarer_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database();
```

### 2. Sea Experience ID Mapping
**Output columns**: `legacy_sea_experience_id, new_sea_experience_id`
**migration.table_mappings**: `target_table='seafarer_sea_experiences'`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE sea_experience_id_mapping AS
SELECT DISTINCT
    sac_se.id AS legacy_sea_experience_id,
    tm.target_id AS new_sea_experience_id
FROM dblink('synergy_seafarer',
    'SELECT id, COALESCE(uuid, NULL::uuid) AS uuid FROM public.sea_experiences WHERE id IS NOT NULL'
) AS sac_se(id bigint, uuid uuid)
JOIN migration.table_mappings tm ON tm.source_id::uuid = sac_se.uuid
WHERE tm.target_table = 'seafarer_sea_experiences'
  AND tm.target_db = current_database()
  AND sac_se.uuid IS NOT NULL;
```

### 3. Vessel Pool ID Mapping
**Output columns**: `legacy_vessel_pool_id, new_vessel_pool_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_id,
    target_id AS new_vessel_pool_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pools''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

### 4. Vessel Pool Mappings ID Mapping
**Output columns**: `legacy_vessel_pool_mappings_id, new_vessel_pool_mappings_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_pool_mappings_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_vessel_pool_mappings_id,
    target_id AS new_vessel_pool_mappings_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings
     WHERE target_table = ''vessel_pool_mappings''
       AND source_id ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'''
) AS tm(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/sea_experience_vessel_pool_migration.sql`

## Validation

- Run `05-validation/crewing/sea_experience_vessel_pool_validation.sql` if available
- Run `06-rollback/crewing/sea_experience_vessel_pool_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
