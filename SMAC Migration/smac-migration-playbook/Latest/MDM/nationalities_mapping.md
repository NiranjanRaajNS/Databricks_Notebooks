# Table Mapping: nationalities → nationalities

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: nationalities
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: nationalities
- **Source Script**: `04-migration-scripts/master/nationalities_migration.sql`

- **Legacy Path**: `synergy_master.public.nationalities`
- **New Path**: `smac_master_migration.public.nationalities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Nationalities (`nationalities` → `nationalities`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `code` from `iso_code` when present; fallback `generate_meaningful_code(TRIM(name), '')` when `iso_code` is NULL/empty
- `country_id` resolved via `country_id_mapping` — match on `iso_code` (case-insensitive) OR `country_name = name`
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0)
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql`
- Filter: only rows where `TRIM(name) <> ''` are migrated
- Pre-migration duplicate UUID check on SAC `uuid` column
- Requires `countries` table migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.nationalities` before insert (full table reload)
- Orchestration dependencies: `countries`
- `DISTINCT ON (uuid)` prevents duplicate rows when multiple country matches exist

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `c.iso_code`, `country_name`, `country_id` | - | - |

### `country_id_mapping`

- **Output columns**: c.iso_code, country_name, country_id

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    c.iso_code,
    c.name as country_name,
    c.id as country_id
FROM public.countries c
WHERE c.deleted_at IS NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 3 | `iso_code`, `name` | text | `code` | text | `COALESCE(NULLIF(TRIM(iso_code), ''), generate_meaningful_code(TRIM(name), ''))` | Prefer `iso_code`; generate from name when empty; NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | No equivalent in SAC; not populated |
| 5 | `iso_code`, `name` | text | `country_id` | uuid | Join `country_id_mapping` on `UPPER(iso_code)` match OR `country_name = name` | Lookup: migrated `public.countries` (non-deleted); nullable if no match |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 13 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (uuid preserved as `id`) |
| 14 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 15 | `iso_code`, `name` | text | `tags` | text[] | Distinct array: lowercase `iso_code` tag + normalized lowercase `name` tag | Derived search tags; not in SAC source |
| 16 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 17 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 18 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `c.iso_code, country_name, country_id`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    c.iso_code,
    c.name as country_name,
    c.id as country_id
FROM public.countries c
WHERE c.deleted_at IS NULL;
```

Full migration context: `04-migration-scripts/master/nationalities_migration.sql`

## Validation

- Run `05-validation/master/nationalities_validation.sql` if available
- Run `06-rollback/master/nationalities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
