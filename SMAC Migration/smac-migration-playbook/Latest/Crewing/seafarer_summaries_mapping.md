# Table Mapping: seafarer_summaries → seafarer_summaries

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_summaries
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_summaries
- **Source Script**: `04-migration-scripts/crewing/seafarer_summaries_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_summaries`
- **New Path**: `smac_crewing_migration.shore.seafarer_summaries`

## Business Key

- **Business Key**: `seafarer_id`
- **Source (orchestration)**: Seafarer Summaries (`seafarer_summaries` → `seafarer_summaries`)

## Migration Notes

- Source `seafarer_summaries` → `shore.seafarer_summaries` (1:1 per seafarer)
- `id` via `gen_random_uuid()` — legacy bigint `id` not preserved (not idempotent)
- `seafarer_id` (bigint) → uuid via `seafarers_id_mapping`; nil UUID fallback
- JSONB arrays transformed to objects keyed by `section_identifier` via `pg_temp.transform_json_array_to_object()`
- Post-migration UPDATE renames `other_details` → `important_declarations` in `section_summary`
- `overall_completeness_percentage` hardcoded `0.0`; `status` hardcoded `'Active'`
- Uses `migration.build_audit_info()` for audit columns
- Requires `seafarers` migrated first

## Special Considerations

- Maps seafarer_id via migration.table_mappings from current database (smac_crewing_migration)
- Script performs `TRUNCATE TABLE shore.seafarer_summaries` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check if | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Purpose**: Check if
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | Legacy `id` not preserved; not idempotent |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; nil UUID fallback | |
| 3 | `section_summary` | jsonb | `section_summary` | jsonb | Array → object keyed by `section_identifier`; post-UPDATE key rename | `other_details` → `important_declarations` |
| 4 | — | — | `overall_completeness_percentage` | numeric(5,2) | Hardcoded `0.0` | Not calculated from source |
| 5 | `is_complete` | boolean | `is_complete` | boolean | `COALESCE(is_complete, false)` | |
| 6 | `authentication_summary` | jsonb | `authentication_summary` | jsonb | Array → object transform | |
| 7 | `internal_document_summary` | jsonb | `internal_document_summary` | jsonb | Array → object transform; default `{}` | |
| 8 | `expiring_document_summary` | jsonb | `expiring_document_summary` | jsonb | Array → object transform | |
| 9 | — | — | `status` | text | Hardcoded `'Active'` | SAC has no status column |
| 10 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 12 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 13 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 14 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at` |
| 15 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` | No `legacy_id` |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** `id` (bigint) — not used for target `id`; `created_by_name`, `updated_by_name` — selected but unused.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check if
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_summaries_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_summaries_validation.sql` if available
- Run `06-rollback/crewing/seafarer_summaries_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
