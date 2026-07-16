# Table Mapping: vessel_owners → vessel_owners

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: owners
- **Source Script**: `04-migration-scripts/master/vessel_owners_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Owners (`vessel_owners` → `owners`)

## Migration Notes

- Combined UNION from 4 SAC tables → `vessel.owners`: `vessel_owners` (GRP), `vessel_registered_owners` (REG), `vessel_bare_boat_owner` (CSE), `vessel_beneficiary_owner` (BEN)
- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` per source table
- `owner_type_id` from `vessel.owner_types` by code (GRP/REG/CSE)
- `country_id` via `countries_id_mapping` with `countries_fallback_mapping` for deleted countries
- `address` JSONB from `address`, `zipcode`, `city`, `city_google_place_id`
- Post-migration UPDATE: re-point `country_id` to active country with same name when mapped country is deleted
- `DISTINCT ON (id)` across UNION sources
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.owners` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | FK lookup | `legacy_id`, `new_id`, `country_name` | `migration.table_mappings` (see SQL) | - |
| `countries_fallback_mapping` | Get BEN (Beneficiary) UUID from owner_types table | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `countries_id_mapping`

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

- **Purpose**: Get BEN (Beneficiary) UUID from owner_types table
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
| 1 | `identifier, id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC uuid as SMAC id |
| 2 | `name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | Generated code |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | `—` | — | `description` | text | `NULL` | Not in SAC source |
| 5 | `contact_number` | text | `contact_number` | text | `TRIM(contact_number)` | Direct copy |
| 6 | `address, zipcode, city, city_google_place_id` | text | `address` | jsonb | `jsonb_build_object` when address non-empty; else `NULL` | Structured address JSON |
| 7 | `country_id` | bigint | `country_id` | uuid | `countries_id_mapping` + `countries_fallback_mapping` | FK lookup with deleted-country fallback |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 10 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | All records migrated |
| 14 | `—` | — | `archived_at` | timestamp with time zone | `NULL` | Not in SAC source |
| 15 | `created_by_id, updated_by_id, created_by_name, updated_by_name, audit_info` | text, jsonb | `audit_info` | jsonb | `migration.build_audit_info()` — per-source pattern with name notes | Pattern 4; no `legacy_id` |
| 16 | `source table` | — | `owner_type_id` | uuid | GRP from `vessel_owners`; REG from `vessel_registered_owners`; CSE from bare boat/beneficiary | Lookup `vessel.owner_types.code` |
| 17 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 18 | `—` | — | `tags` | text[] | `NULL` | Not populated |
| 19 | `status, deleted_at` | text, timestamp | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 20 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 21 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |

"**SAC columns not migrated:** `city_id` (vessel_owners only

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
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
**Purpose**: Get BEN (Beneficiary) UUID from owner_types table
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

Full migration context: `04-migration-scripts/master/vessel_owners_migration.sql`

## Validation

- Run `05-validation/master/vessel_owners_validation.sql` if available
- Run `06-rollback/master/vessel_owners_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
