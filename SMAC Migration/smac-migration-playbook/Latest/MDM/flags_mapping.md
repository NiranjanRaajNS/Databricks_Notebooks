# Table Mapping: flags → flags

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: flags
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: flags
- **Source Script**: `04-migration-scripts/master/flags_migration.sql`

- **Legacy Path**: `synergy_vessel.public.flags`
- **New Path**: `smac_master_migration.public.flags`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Flags (`flags` → `flags`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = source_identifier`
- `code` prefers country `iso_code` from joined `countries` table; falls back to `generate_meaningful_code(flag_name, identifier)`
- `country_id` mapped via `country_id_mapping` (`migration.table_mappings` where `target_table = 'countries'`)
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0) — Case 1
- `audit_info` maps SAC `created_by_id`/`updated_by_id` and names via `build_audit_info()`
- Filter: only rows where `identifier IS NOT NULL AND TRIM(COALESCE(name, '')) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Requires `countries` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE public.flags` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `legacy_id`, `new_id`, `iso_code` | `migration.table_mappings` (see SQL) | - |

### `country_id_mapping`

- **Output columns**: legacy_id, new_id, iso_code
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_id,
    tm.target_id AS new_id,
    c.iso_code AS iso_code
FROM migration.table_mappings tm
JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `identifier`, `country` (iso) | text, uuid, bigint | `code` | text | `COALESCE(NULLIF(TRIM(iso_code), ''), generate_meaningful_code(TRIM(name), identifier::text))` | Prefers country ISO code; fallback generated from name |
| 3 | `name` | text | `name` | text | `COALESCE(TRIM(name), 'UNKNOWN')` | Direct copy; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with trim |
| 5 | `country` | bigint | `country_id` | uuid | Map via `country_id_mapping`; join on `legacy_id = country::bigint` | Lookup: `migration.table_mappings` where `target_table = 'countries'` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 13 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — SAC audit IDs and names mapped; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |
| 14 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 15 | — | — | `tags` | text[] | `ARRAY[]::text[]` | Empty array; not in SAC source |
| 16 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 17 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 18 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SMAC columns not migrated:** None — all target columns populated from SAC or defaults.

**SAC columns not migrated:** None significant — all SAC columns used in mapping or defaults.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `legacy_id, new_id, iso_code`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_id,
    tm.target_id AS new_id,
    c.iso_code AS iso_code
FROM migration.table_mappings tm
JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/flags_migration.sql`

## Validation

- Run `05-validation/master/flags_validation.sql` if available
- Run `06-rollback/master/flags_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
