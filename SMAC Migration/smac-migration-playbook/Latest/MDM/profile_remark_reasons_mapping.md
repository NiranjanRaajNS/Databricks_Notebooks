# Table Mapping: profile_remark_reasons → profile_remark_reasons

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_profile_remarks (distinct extraction)
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: profile_remark_reasons
- **Source Script**: `04-migration-scripts/master/profile_remark_reasons_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_profile_remarks`
- **New Path**: `smac_master_migration.crewing.profile_remark_reasons`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Profile Remarks (`seafarer_profile_remarks` → `profile_remark_reasons`)

## Migration Notes

- Extracts **distinct** `name` values from `seafarer_profile_remarks` (not a 1:1 row migration)
- `legacy_id` = `MIN(id)` per distinct normalized `name`; idempotent UUID via `migration.resolve_target_id()` with `p_target_id = NULL`
- `description` aggregated as `MAX(TRIM(description))` per distinct name
- `type` → `profile_remark_type_id` via `profile_remark_type_mapping` (code/name match with fallbacks)
- `code` generated from `name` via `generate_meaningful_code()`
- Timestamps: `MIN(created_at)`, `MAX(updated_at)` per distinct name
- Filter: `name IS NOT NULL` and `TRIM(name) <> ''`
- Cleans non-numeric `source_id` mappings before migration

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.profile_remark_reasons` before insert (full table reload)
- Requires `profile_remark_types` seeded before migration
- `DISTINCT ON (LOWER(TRIM(reason_name)))` prevents duplicate reason names

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `profile_remark_type_mapping` | Check for duplicate UUIDs in source table (if uuid column exists) | `name_lower`, `code_lower`, `target_id` | - | - |

### `profile_remark_type_mapping`

- **Purpose**: Check for duplicate UUIDs in source table (if uuid column exists)
- **Output columns**: name_lower, code_lower, target_id

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    LOWER(TRIM(code)) AS code_lower,
    id AS target_id
FROM crewing.profile_remark_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` (aggregated) | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `MIN(id)::text`; `p_target_id = NULL` | Representative legacy id per distinct name; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from distinct `name`; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `LEFT(COALESCE(name, 'UNKNOWN'), 255)` | Distinct trimmed name; truncated to 255 chars |
| 4 | `description` | text | `description` | text | `LEFT(COALESCE(MAX(description), ''), 1000)` | Aggregated max description per distinct name |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 7 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in source; all distinct reasons active |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `MIN(created_at)` per distinct name; `COALESCE(..., NOW())` | Earliest timestamp from grouped rows |
| 13 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `MAX(updated_at)` per distinct name; fallback to `created_at` | Latest timestamp from grouped rows |
| 14 | — | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source (distinct extraction) |
| 15 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `name`, `description` | text | `audit_info` | jsonb | `migration.build_audit_info()` — legacy name/description in `notes` | Standardized SMAC audit structure; no audit columns in SAC |
| 17 | — | — | `tags` | text[] | Hardcoded `ARRAY[]::text[]` | Empty array; not in SAC source |
| 18 | `type` | text | `profile_remark_type_id` | uuid | Match via `profile_remark_type_mapping` — exact code/name, then inactive→deactivation, active→activation, partial match | Lookup: `crewing.profile_remark_types`; NULL when no match |

**SAC columns not migrated individually:** Source rows are deduplicated by `name` — individual `seafarer_profile_remarks.id` values (except `MIN(id)` for mapping) are not preserved as separate SMAC records.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `profile_remark_types` (seed data required before migration)

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Profile Remark Type ID Mapping
**Purpose**: Check for duplicate UUIDs in source table (if uuid column exists)
**Output columns**: `name_lower, code_lower, target_id`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    LOWER(TRIM(code)) AS code_lower,
    id AS target_id
FROM crewing.profile_remark_types;
```

Full migration context: `04-migration-scripts/master/profile_remark_reasons_migration.sql`

## Validation

- Run `05-validation/master/profile_remark_reasons_validation.sql` if available
- Run `06-rollback/master/profile_remark_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
