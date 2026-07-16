# Table Mapping: vessels → vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessels
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessels
- **Source Script**: `04-migration-scripts/master/vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessels`
- **New Path**: `smac_master_migration.vessel.vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `name` prefers `vessel_details.name` over `vessels.name` via `vessel_details_lookup` (active revision first)
- `class_no`, `ship_builder_id`, `yard_country_id` sourced from `vessel_details` (not `vessels` table directly)
- FK lookups: `category_id_mapping`, `vessel_sub_category_id_mapping`, `country_id_mapping`, `ship_builder_id_mapping`
- `vessel_status` and `status` are separate integer fields with different mapping rules
- `status` derived from `deleted_at` + `status` text (Rule 2.2.1 Case 2: `legacy_deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'1'→0; INACTIVE/'0'→2; DELETED/'3'→3; ELSE 0)
- Pre-migration duplicate UUID check on SAC `uuid` column
- Requires `categories`, `sub_categories`, `ship_builders`, `countries` migrated first

## Special Considerations

- Rule 2.2.1 Case 2: `deleted_at` takes precedence over `status`
- Script performs `TRUNCATE TABLE vessel.vessels` before insert (full table reload)
- `audit_info` uses `SYSTEM_USER_ID`; names from SAC stored in `notes`
- Orchestration dependencies: `categories`, `countries`, `sub_categories`, `ship_builders`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `category_id_mapping` | FK lookup | `source_category_id`, `target_category_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_sub_category_id_mapping` | FK lookup | `source_sub_category_id`, `target_sub_category_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `country_id_mapping` | FK lookup | `source_country_id`, `target_country_id` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `ship_builder_id_mapping` | FK lookup | `source_ship_builder_id`, `target_ship_builder_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_details_lookup` | FK lookup | `legacy_vessel_id`, `vd.class_no`, `vessel_name`, `legacy_yard_country_id`, `legacy_ship_builder_id` | - | `synergy_vessel` |

### `category_id_mapping`

- **Output columns**: source_category_id, target_category_id
- **migration.table_mappings**: target_table=categories
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS source_category_id,
    vc.identifier::uuid AS target_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_categories'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### `vessel_sub_category_id_mapping`

- **Output columns**: source_sub_category_id, target_sub_category_id
- **migration.table_mappings**: target_table=sub_categories
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vsc.id::bigint AS source_sub_category_id,
    vsc.identifier::uuid AS target_sub_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_sub_categories'
) AS vsc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'sub_categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vsc.id
);
```

### `country_id_mapping`

- **Output columns**: source_country_id, target_country_id
- **migration.table_mappings**: target_table=countries
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_country_id,
    target_id AS target_country_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    c.id::bigint AS source_country_id,
    c.uuid::uuid AS target_country_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(
    id bigint,
    uuid uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'countries'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = c.id
);
```

### `ship_builder_id_mapping`

- **Output columns**: source_ship_builder_id, target_ship_builder_id
- **migration.table_mappings**: target_table=ship_builders
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE ship_builder_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS source_ship_builder_id,
    target_id AS target_ship_builder_id
FROM migration.table_mappings
WHERE target_table = 'ship_builders'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    sb.identifier::uuid AS source_ship_builder_id,
    sb.identifier::uuid AS target_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.ship_builders WHERE identifier IS NOT NULL'
) AS sb(
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'ship_builders'
      AND tm.target_db = current_database()
      AND tm.source_id::uuid = sb.identifier
);
```

### `vessel_details_lookup`

- **Output columns**: legacy_vessel_id, vd.class_no, vessel_name, legacy_yard_country_id, legacy_ship_builder_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.class_no,
    vd.name AS vessel_name,
    vd.yard_country_id AS legacy_yard_country_id,
    vd.ship_builder AS legacy_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT vessel_id, class_no, name, yard_country_id, ship_builder, status, updated_at
     FROM public.vessel_details
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    class_no text,
    name text,
    yard_country_id bigint,
    ship_builder uuid,
    status text,
    updated_at timestamp
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `vessel_details.name`, `name` | text | `name` | text | `COALESCE(TRIM(vessel_name), TRIM(name), 'UNKNOWN')` | Prefer name from `vessel_details_lookup`; NOT NULL in SMAC |
| 3 | `imo_number` | bigint | `imo_number` | text | `COALESCE(imo_number::text, '')` | Cast bigint to text; empty string when NULL |
| 4 | `vessel_category_id` | bigint | `category_id` | uuid | Map via `category_id_mapping` | Lookup: `migration.table_mappings` (`categories`) + `vessel_categories.identifier` fallback |
| 5 | `vessel_sub_category_id` | bigint | `sub_category_id` | uuid | Map via `vessel_sub_category_id_mapping` | Lookup: `migration.table_mappings` (`sub_categories`) + `vessel_sub_categories.identifier` fallback |
| 6 | `vessel_status`, `status`, `deleted_at` | text, text, timestamp | `vessel_status` | integer | Map `vessel_status` text or fallback from `status`/`deleted_at` to SMAC vessel status enum (0=Draft, 3=Active, 8=Inactive/Deleted) | Separate from SMAC `status` column; uses different integer scale |
| 7 | `vessel_details.class_no` | text | `class_no` | text | `TRIM(class_no)` from `vessel_details_lookup` | Sourced from active `vessel_details` row, not `vessels` table |
| 8 | `vessel_details.ship_builder` | uuid | `ship_builder_id` | uuid | Map via `ship_builder_id_mapping` on `vessel_details.ship_builder` | Lookup: `migration.table_mappings` (`ship_builders`) + identifier fallback |
| 9 | `vessel_details.yard_country_id` | bigint | `yard_country_id` | uuid | Map via `country_id_mapping` on `vessel_details.yard_country_id` | Lookup: `migration.table_mappings` (`countries`) + `synergy_master.countries.uuid` fallback |
| 10 | `keel_laid` | timestamp without time zone | `keel_laid` | timestamp without time zone | Direct copy | From `vessels` table |
| 11 | `built_year` | integer | `built_year` | integer | Direct copy | From `vessels` table |
| 12 | `build_date` | date | `build_on` | timestamp without time zone | Cast `build_date` to timestamp when present; else NULL | SAC `build_date` renamed to `build_on` |
| 13 | `launched` | timestamp without time zone | `launched` | timestamp without time zone | Direct copy | From `vessels` table |
| 14 | `delivered` | timestamp without time zone | `delivered` | timestamp without time zone | Direct copy | From `vessels` table |
| 15 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 16 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 18 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 19 | `deleted_at`, `status` | timestamp without time zone, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 20 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 21 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 22 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 23 | `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; names in `notes` | No `legacy_id` (uuid preserved as `id`) |
| 24 | `vessel_details.name`, `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY name) - 1` | Sequential hierarchy index sorted by vessel name |

**SAC columns not migrated:** `official_number` — present in `vessels` staging but not inserted into SMAC `vessel.vessels`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`
- `countries`
- `flags`
- `migrations`
- `ports`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Category ID Mapping
**Output columns**: `source_category_id, target_category_id`
**migration.table_mappings**: `target_table='categories'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS source_category_id,
    vc.identifier::uuid AS target_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_categories'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### 2. Vessel Sub Category ID Mapping
**Output columns**: `source_sub_category_id, target_sub_category_id`
**migration.table_mappings**: `target_table='sub_categories'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vsc.id::bigint AS source_sub_category_id,
    vsc.identifier::uuid AS target_sub_category_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_sub_categories'
) AS vsc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'sub_categories'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vsc.id
);
```

### 3. Country ID Mapping
**Output columns**: `source_country_id, target_country_id`
**migration.table_mappings**: `target_table='countries'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS source_country_id,
    target_id AS target_country_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    c.id::bigint AS source_country_id,
    c.uuid::uuid AS target_country_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries WHERE uuid IS NOT NULL'
) AS c(
    id bigint,
    uuid uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'countries'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = c.id
);
```

### 4. Ship Builder ID Mapping
**Output columns**: `source_ship_builder_id, target_ship_builder_id`
**migration.table_mappings**: `target_table='ship_builders'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE ship_builder_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS source_ship_builder_id,
    target_id AS target_ship_builder_id
FROM migration.table_mappings
WHERE target_table = 'ship_builders'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    sb.identifier::uuid AS source_ship_builder_id,
    sb.identifier::uuid AS target_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT identifier FROM public.ship_builders WHERE identifier IS NOT NULL'
) AS sb(
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'ship_builders'
      AND tm.target_db = current_database()
      AND tm.source_id::uuid = sb.identifier
);
```

### 5. Vessel Details ID Mapping
**Output columns**: `legacy_vessel_id, vd.class_no, vessel_name, legacy_yard_country_id, legacy_ship_builder_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.class_no,
    vd.name AS vessel_name,
    vd.yard_country_id AS legacy_yard_country_id,
    vd.ship_builder AS legacy_ship_builder_id
FROM dblink('synergy_vessel',
    'SELECT vessel_id, class_no, name, yard_country_id, ship_builder, status, updated_at
     FROM public.vessel_details
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    class_no text,
    name text,
    yard_country_id bigint,
    ship_builder uuid,
    status text,
    updated_at timestamp
);
```

Full migration context: `04-migration-scripts/master/vessels_migration.sql`

## Validation

- Run `05-validation/master/vessels_validation.sql` if available
- Run `06-rollback/master/vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
