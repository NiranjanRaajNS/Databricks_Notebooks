# Table Mapping: ship_builders → ship_builders

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: ship_builders
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: ship_builders
- **Source Script**: `04-migration-scripts/master/ship_builders_migration.sql`

- **Legacy Path**: `synergy_vessel.public.ship_builders`
- **New Path**: `smac_master_migration.vessel.ship_builders`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Builders (`ship_builders` → `ship_builders`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`; source_id also uses `identifier::text`
- `country_id` mapped via `countries_id_mapping` (active countries) with `countries_fallback_mapping` for deleted-country name match
- Post-migration UPDATE remaps `country_id` when referenced country is deleted (match by country name)
- `status` derived from `deleted_at` only (Case 1)
- Filter: `identifier IS NOT NULL`
- Duplicate UUID check on `identifier` is commented out in script

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.ship_builders` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id`, `country_name` | `migration.table_mappings` (see SQL) | - |
| `countries_fallback_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `countries_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id, country_name
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### `countries_fallback_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | Generated business code; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | — | — | `description` | text | Hardcoded NULL | No description in SAC source |
| 5 | `address` | text | `address` | jsonb | `jsonb_build_object('full_address', TRIM(address))` when address present; else NULL | Plain text wrapped in JSONB structure |
| 6 | `country_id` | bigint | `country_id` | uuid | `COALESCE(countries_id_mapping.new_id, countries_fallback_mapping.new_id)` | FK via `migration.table_mappings` where `target_table = 'countries'`; fallback matches deleted country by name |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 13 | `update_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(update_at, created_at, NOW())` | SAC column is `update_at` (not `updated_at`) |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name)) - 1` | Zero-based alphabetical hierarchy index |
| 16 | `name`, `identifier` | text, uuid | `tags` | text[] | Array of lowercase code tag + normalized name slug; single tag when identical | Derived search tags |
| 17 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**SAC columns not migrated:** `status` (text), `audit_info` (jsonb) — not used in target mapping.

**Post-migration changes (not from SAC column mapping):** UPDATE `country_id` to active country when referenced country is deleted (name match).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id, country_name`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### 2. Countries Fallback ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

Full migration context: `04-migration-scripts/master/ship_builders_migration.sql`

## Validation

- Run `05-validation/master/ship_builders_validation.sql` if available
- Run `06-rollback/master/ship_builders_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
