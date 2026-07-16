# Table Mapping: ports → ports

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ports
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: ports
- **Source Script**: `04-migration-scripts/master/ports_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ports`
- **New Path**: `smac_master_migration.public.ports`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ports (`ports` → `ports`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `country_id` mapped via `country_id_mapping` (`migration.table_mappings` where `target_table = 'countries'`)
- `timezones_id` mapped via `timezone_id_mapping` — embedded `timezone-list.csv` matched to `countries.iso_code` and `time_zones.name`
- `code` from `iso_code` when present; fallback `generate_meaningful_code(port_name)`
- Latitude/longitude sign adjusted by direction (`S` → negative lat, `W` → negative long)
- `status`: `deleted_at IS NOT NULL` OR `isdeleted = true` → Deleted (3); else Active (0)
- `level` assigned via `ROW_NUMBER()` ordered by port name
- Pre-migration duplicate UUID check on SAC `identifier` column
- Second INSERT adds seed record `'At Sea'` (not from SAC)

## Special Considerations

- Script performs `TRUNCATE TABLE public.ports` before insert (full table reload)
- Requires `countries` and `time_zones` tables migrated first for FK/timezone resolution

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `source_id::text`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `timezone_id_mapping` | FK lookup | `country_id`, `timezone_id` | - | - |

### `country_id_mapping`

- **Output columns**: source_id::text, target_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

### `timezone_id_mapping`

- **Output columns**: country_id, timezone_id

```sql
CREATE TEMP TABLE timezone_id_mapping AS
SELECT DISTINCT ON (c.id)
    c.id AS country_id,
    tz.id AS timezone_id
FROM timezone_csv_data csv
INNER JOIN public.countries c ON UPPER(TRIM(csv.country_code)) = UPPER(TRIM(c.iso_code))
INNER JOIN public.time_zones tz ON TRIM(csv.timezone_iana) = TRIM(tz.name)
WHERE csv.country_code IS NOT NULL
  AND TRIM(csv.country_code) <> ''
  AND csv.timezone_iana IS NOT NULL
  AND TRIM(csv.timezone_iana) <> ''
ORDER BY c.id, tz.name;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `iso_code`, `name` | character varying, text | `code` | text | `COALESCE(NULLIF(TRIM(iso_code), ''), generate_meaningful_code(TRIM(port_name), ''))` | Prefer port `iso_code`; generate from name when empty; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `COALESCE(port_name, 'UNKNOWN')` | Direct copy; defaults to `'UNKNOWN'`; NOT NULL in SMAC |
| 4 | `discription` | character varying | `description` | text | `TRIM(COALESCE(discription, ''))` | SAC column has typo `discription` |
| 5 | `country_id` | bigint | `country_id` | uuid | Map via `country_id_mapping` on `legacy_country_id` | Lookup: `migration.table_mappings` where `target_table = 'countries'` |
| 6 | `city`, `country_id` | character varying, bigint | `address` | jsonb | `jsonb_build_object` with `city`, `addressLine1` = city + country name; other fields NULL | Built when `city` is non-empty; joins migrated country for name |
| 7 | `latitude`, `latitude_direction` | numeric, character varying | `latitude` | numeric | Negate when `latitude_direction = 'S'`; else direct copy | Direction-aware coordinate conversion |
| 8 | `longitude`, `longitude_direction` | numeric, character varying | `longitude` | numeric | Negate when `longitude_direction = 'W'`; else direct copy | Direction-aware coordinate conversion |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 10 | — | — | `parent_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 11 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 16 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 17 | `country_id` | bigint | `timezones_id` | uuid | Join `timezone_id_mapping` on mapped `country_id`; default nil UUID | Lookup: embedded CSV → `countries.iso_code` → `time_zones.name` |
| 18 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(port_name))` | Sequential values sorted alphabetically by port name |
| 19 | `iso_code`, `name` | character varying, text | `tags` | text[] | Array: `code` + normalized lowercase `name` tag | Derived search tags; not in SAC source |
| 20 | `deleted_at`, `isdeleted` | timestamp without time zone, boolean | `status` | integer | `deleted_at IS NOT NULL` OR `isdeleted = true` → Deleted (3); else Active (0) | Combined deletion indicators from SAC |
| 21 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 22 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SAC columns not migrated:** `short_name` — not referenced in migration script.

**Post-migration seed record (not from SAC):** `'At Sea'` port inserted via second INSERT block with `gen_random_uuid()`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `source_id::text, target_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

### 2. Timezone ID Mapping
**Output columns**: `country_id, timezone_id`

```sql
CREATE TEMP TABLE timezone_id_mapping AS
SELECT DISTINCT ON (c.id)
    c.id AS country_id,
    tz.id AS timezone_id
FROM timezone_csv_data csv
INNER JOIN public.countries c ON UPPER(TRIM(csv.country_code)) = UPPER(TRIM(c.iso_code))
INNER JOIN public.time_zones tz ON TRIM(csv.timezone_iana) = TRIM(tz.name)
WHERE csv.country_code IS NOT NULL
  AND TRIM(csv.country_code) <> ''
  AND csv.timezone_iana IS NOT NULL
  AND TRIM(csv.timezone_iana) <> ''
ORDER BY c.id, tz.name;
```

Full migration context: `04-migration-scripts/master/ports_migration.sql`

## Validation

- Run `05-validation/master/ports_validation.sql` if available
- Run `06-rollback/master/ports_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
