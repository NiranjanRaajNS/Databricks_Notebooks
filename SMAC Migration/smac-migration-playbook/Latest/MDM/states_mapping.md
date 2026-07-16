# Table Mapping: states → states

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: states
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: states
- **Source Script**: `04-migration-scripts/master/states_migration.sql`

- **Legacy Path**: `synergy_master.public.states`
- **New Path**: `smac_master_migration.public.states`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: States (`states` → `states`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `country_id` mapped via `country_id_mapping` (non-deleted countries only); rows without valid country mapping excluded (`WHERE country_map.target_id IS NOT NULL`)
- Post-migration UPDATE sets `country_id = NULL` when referenced country is deleted
- `code` generated from `name` + `identifier` via `generate_meaningful_code()`
- `status` derived from `deleted_at` only (Case 1)
- Filter: `name IS NOT NULL`
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.states` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | Check if any mapp | `DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint`, `tm.target_id` | `migration.table_mappings` (see SQL) | - |

### `country_id_mapping`

- **Purpose**: Check if any mapp
- **Output columns**: DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint, tm.target_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint,
    tm.target_id
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL
ORDER BY tm.source_id::bigint, tm.target_id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 3 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | Generated business code |
| 4 | `country_id` | bigint | `country_id` | uuid | Map via `country_id_mapping`; join on `source_id = country_id` | Only non-deleted countries; rows without mapping excluded |
| 5 | — | — | `description` | text | Hardcoded NULL | No description in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `name` | text | `level` | numeric(10,1) | `ROW_NUMBER() OVER (ORDER BY TRIM(name))` | Sequential index sorted alphabetically by name |
| 17 | — | — | `tags` | text[] | Hardcoded `ARRAY[]::text[]` | Empty array; not in SAC source |
| 18 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` — UUID validation for created/updated by IDs; names in `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**Post-migration changes (not from SAC column mapping):** UPDATE sets `country_id = NULL` when referenced country has `deleted_at IS NOT NULL`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Purpose**: Check if any mapp
**Output columns**: `DISTINCT ON (tm.source_id::bigint) tm.source_id::bigint, tm.target_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT DISTINCT ON (tm.source_id::bigint)
    tm.source_id::bigint,
    tm.target_id
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL
ORDER BY tm.source_id::bigint, tm.target_id;
```

Full migration context: `04-migration-scripts/master/states_migration.sql`

## Validation

- Run `05-validation/master/states_validation.sql` if available
- Run `06-rollback/master/states_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
