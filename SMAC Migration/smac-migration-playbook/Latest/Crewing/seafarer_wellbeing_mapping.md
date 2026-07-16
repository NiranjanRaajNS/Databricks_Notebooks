# Table Mapping: seafarer_wellbeing → seafarer_wellbeing

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_wellbeing
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_wellbeing
- **Source Script**: `04-migration-scripts/crewing/seafarer_wellbeing_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_wellbeing`
- **New Path**: `smac_crewing_migration.shore.seafarer_wellbeing`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Wellbeing (`seafarer_wellbeing` → `seafarer_wellbeing`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`; duplicate UUID check
- `contract_id` (bigint) mapped to uuid via `contract_id_mapping` when `> 0`; else NULL
- `metadata` normalized and remapped: `RankId`, `VesselId`, `VesselTypeId` from SAC integers to master UUIDs; wrapped as JSON array
- `seafarer_uuid`, `form_response`, `status` carried directly; `created_at`/`updated_at` set to `NOW()` (not from legacy)
- `audit_info` copied directly from source when valid JSONB object; not rebuilt via `build_audit_info`
- `deleted_at`, `workflow_instance_id` not populated
- Requires `seafarers`, `seafarer_contracts` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_wellbeing` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_contracts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_sac_to_smac_uuid` | FK lookup | `tm.source_id`, `tm.target_id`, `pri` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id`, `pri` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id`, `pri` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `contract_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `rank_sac_to_smac_uuid`

- **Output columns**: tm.source_id, tm.target_id, pri
- **migration.table_mappings**: source_db=, source_schema=, source_table=, target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
WITH map AS (
    SELECT
        tm.source_id,
        tm.target_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''public''
            AND tm.target_table = ''ranks''
            AND tm.source_db = ''synergy_master''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''ranks'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        r.id::text AS source_id,
        r.identifier AS target_id,
        2 AS pri
    FROM dblink(
        'synergy_master',
        'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
    ) AS r(id bigint, identifier uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.source_id = r.id::text)
)
SELECT DISTINCT ON (u.source_id)
    u.source_id,
    u.target_id
FROM (
    SELECT map.source_id, map.target_id, map.pri FROM map
    UNION ALL
    SELECT fb.source_id, fb.target_id, fb.pri FROM fb
) u
ORDER BY u.source_id, u.pri;
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id, pri
- **migration.table_mappings**: source_db=, source_schema=, source_table=, target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
WITH map AS (
    SELECT
        tm.source_id::bigint AS legacy_id,
        tm.target_id AS new_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''vessel''
            AND tm.target_table = ''vessels''
            AND tm.source_db = ''synergy_vessel''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''vessels''
            AND tm.source_id ~ ''^[0-9]+$'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        v.id AS legacy_id,
        v.uuid AS new_id,
        2 AS pri
    FROM dblink(
        'synergy_vessel',
        'SELECT id, uuid FROM public.vessels WHERE uuid IS NOT NULL'
    ) AS v(id bigint, uuid uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.legacy_id = v.id)
)
SELECT DISTINCT ON (u.legacy_id)
    u.legacy_id,
    u.new_id
FROM (
    SELECT map.legacy_id, map.new_id, map.pri FROM map
    UNION ALL
    SELECT fb.legacy_id, fb.new_id, fb.pri FROM fb
) u
ORDER BY u.legacy_id, u.pri;
```

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id, pri
- **migration.table_mappings**: source_db=, source_schema=, source_table=, target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
WITH map AS (
    SELECT
        tm.source_id::bigint AS legacy_id,
        tm.target_id AS new_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''vessel''
            AND tm.target_table = ''categories''
            AND tm.source_db = ''synergy_vessel''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''vessel_categories''
            AND tm.source_id ~ ''^[0-9]+$'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        vc.id AS legacy_id,
        vc.identifier AS new_id,
        2 AS pri
    FROM dblink(
        'synergy_vessel',
        'SELECT id, identifier FROM public.vessel_categories WHERE identifier IS NOT NULL'
    ) AS vc(id bigint, identifier uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.legacy_id = vc.id)
)
SELECT DISTINCT ON (u.legacy_id)
    u.legacy_id,
    u.new_id
FROM (
    SELECT map.legacy_id, map.new_id, map.pri FROM map
    UNION ALL
    SELECT fb.legacy_id, fb.new_id...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `seafarer_uuid` | uuid | `seafarer_uuid` | uuid | Direct copy | Required |
| 3 | `form_response` | jsonb | `form_response` | jsonb | `COALESCE(form_response, '{}')` | |
| 4 | `is_support_request_needed` | boolean | `is_support_request_needed` | boolean | `COALESCE(is_support_request_needed, false)` | |
| 5 | `metadata` | jsonb | `metadata` | jsonb | Normalize + remap RankId/VesselId/VesselTypeId to UUIDs + array wrap | Multi-step CTE transformation |
| 6 | `contract_id` | bigint | `contract_id` | uuid | Map when `> 0` via `contract_id_mapping`; else NULL | |
| 7 | `status` | character varying | `status` | character varying | `COALESCE(NULLIF(TRIM(status), ''), 'Open')` | |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 9 | — | — | `created_at` | timestamp without time zone | `NOW()` | **Not from legacy** |
| 10 | — | — | `updated_at` | timestamp without time zone | `NOW()` | **Not from legacy** |
| 11 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 12 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Legacy soft-delete not migrated |
| 13 | `audit_info` | jsonb | `audit_info` | jsonb | Direct copy if object; else `{}` | Not rebuilt |
| 14 | — | — | `workflow_instance_id` | uuid | `NULL` | |

**SMAC columns not migrated:** `archived_at`, `deleted_at`, `workflow_instance_id` — set NULL; `created_at`/`updated_at` use `NOW()` not legacy timestamps.

**SAC columns not migrated:** `created_at`, `updated_at`, `deleted_at` (if present on source) — not read in dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_contracts`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Rank Sac To Smac Uuid ID Mapping
**Output columns**: `tm.source_id, tm.target_id, pri`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
WITH map AS (
    SELECT
        tm.source_id,
        tm.target_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''public''
            AND tm.target_table = ''ranks''
            AND tm.source_db = ''synergy_master''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''ranks'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        r.id::text AS source_id,
        r.identifier AS target_id,
        2 AS pri
    FROM dblink(
        'synergy_master',
        'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
    ) AS r(id bigint, identifier uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.source_id = r.id::text)
)
SELECT DISTINCT ON (u.source_id)
    u.source_id,
    u.target_id
FROM (
    SELECT map.source_id, map.target_id, map.pri FROM map
    UNION ALL
    SELECT fb.source_id, fb.target_id, fb.pri FROM fb
) u
ORDER BY u.source_id, u.pri;
```

### 3. Vessels ID Mapping
**Output columns**: `legacy_id, new_id, pri`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
WITH map AS (
    SELECT
        tm.source_id::bigint AS legacy_id,
        tm.target_id AS new_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''vessel''
            AND tm.target_table = ''vessels''
            AND tm.source_db = ''synergy_vessel''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''vessels''
            AND tm.source_id ~ ''^[0-9]+$'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        v.id AS legacy_id,
        v.uuid AS new_id,
        2 AS pri
    FROM dblink(
        'synergy_vessel',
        'SELECT id, uuid FROM public.vessels WHERE uuid IS NOT NULL'
    ) AS v(id bigint, uuid uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.legacy_id = v.id)
)
SELECT DISTINCT ON (u.legacy_id)
    u.legacy_id,
    u.new_id
FROM (
    SELECT map.legacy_id, map.new_id, map.pri FROM map
    UNION ALL
    SELECT fb.legacy_id, fb.new_id, fb.pri FROM fb
) u
ORDER BY u.legacy_id, u.pri;
```

### 4. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id, pri`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
WITH map AS (
    SELECT
        tm.source_id::bigint AS legacy_id,
        tm.target_id AS new_id,
        1 AS pri
    FROM dblink(
        'smac_master_migration',
        'SELECT tm.source_id, tm.target_id FROM migration.table_mappings tm
          WHERE tm.target_db = current_database()
            AND tm.target_schema = ''vessel''
            AND tm.target_table = ''categories''
            AND tm.source_db = ''synergy_vessel''
            AND tm.source_schema = ''public''
            AND tm.source_table = ''vessel_categories''
            AND tm.source_id ~ ''^[0-9]+$'''
    ) AS tm(source_id text, target_id uuid)
),
fb AS (
    SELECT
        vc.id AS legacy_id,
        vc.identifier AS new_id,
        2 AS pri
    FROM dblink(
        'synergy_vessel',
        'SELECT id, identifier FROM public.vessel_categories WHERE identifier IS NOT NULL'
    ) AS vc(id bigint, identifier uuid)
    WHERE NOT EXISTS (SELECT 1 FROM map m WHERE m.legacy_id = vc.id)
)
SELECT DISTINCT ON (u.legacy_id)
    u.legacy_id,
    u.new_id
FROM (
    SELECT map.legacy_id, map.new_id, map.pri FROM map
    UNION ALL
    SELECT fb.legacy_id, fb.new_id, fb.pri FROM fb
) u
ORDER BY u.legacy_id, u.pri;
```

Full migration context: `04-migration-scripts/crewing/seafarer_wellbeing_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_wellbeing_validation.sql` if available
- Run `06-rollback/crewing/seafarer_wellbeing_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
