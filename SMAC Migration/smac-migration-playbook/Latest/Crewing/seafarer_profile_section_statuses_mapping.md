# Table Mapping: seafarer_profile_remarks → seafarer_profile_section_statuses

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_profile_remarks
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_profile_section_statuses
- **Source Script**: `04-migration-scripts/crewing/seafarer_profile_section_statuses_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_profile_remarks`
- **New Path**: `smac_crewing_migration.shore.seafarer_profile_section_statuses`

## Business Key

- **Business Key**: `section_code`
- **Source (orchestration)**: Seafarer Profile Remarks (`seafarer_profile_remarks` → `seafarer_profile_section_statuses`)

## Migration Notes

- Source: SAC `seafarer_profile_remarks` (master remark type definitions, not per-seafarer data)
- `id` generated via `gen_random_uuid()` — SAC has bigint `id` only (no uuid)
- `seafarer_id` hardcoded nil UUID — SAC source has no seafarer reference
- `name` → `section_code`; `type` → `status`
- `completed_fields`, `total_fields` = 0; `completion_pct` = 0.0 (not in SAC)
- `audit_info` uses standard SMAC structure with `legacy_id` for mapping storage
- Mappings stored via `migration.store_table_mappings()` matching on `audit_info->>'legacy_id'`

## Special Considerations

- Source table does not have seafarer_id, so it will be set to NULL
- Script performs `TRUNCATE TABLE shore.seafarer_profile_section_statuses` before insert (full table reload).
- `seafarers_id_mapping` temp table is created but not used (source has no `seafarer_id`)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

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
| 1 | `id` | bigint | `id` | uuid | `gen_random_uuid()` | New UUID per row; SAC id stored in `audit_info.legacy_id` |
| 2 | — | — | `seafarer_id` | uuid | Hardcoded nil UUID | SAC `seafarer_profile_remarks` has no seafarer_id |
| 3 | `name` | text | `section_code` | text | `TRIM(name)` when non-empty; else `NULL` | SAC remark type name → section code |
| 4 | `type` | text | `status` | text | `TRIM(type)` when non-empty; else `NULL` | SAC remark type category |
| 5 | — | — | `completed_fields` | integer | Hardcoded `0` | NOT NULL in SMAC; not in SAC source |
| 6 | — | — | `total_fields` | integer | Hardcoded `0` | NOT NULL in SMAC; not in SAC source |
| 7 | — | — | `completion_pct` | numeric | Hardcoded `0.0` | NOT NULL in SMAC; not in SAC source |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 10 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 11 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 12 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 13 | `created_by_id`, `updated_by_id`, `id` | text, bigint | `audit_info` | jsonb | Standard SMAC `jsonb_build_object()` with `legacy_id` | - |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `description` — not referenced in migration INSERT (may exist in SAC schema).

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
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

Full migration context: `04-migration-scripts/crewing/seafarer_profile_section_statuses_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_profile_section_statuses_validation.sql` if available
- Run `06-rollback/crewing/seafarer_profile_section_statuses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
