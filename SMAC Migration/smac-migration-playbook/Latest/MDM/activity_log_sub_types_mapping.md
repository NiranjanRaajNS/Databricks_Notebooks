# Table Mapping: seafarer_activity_log_sub_types → activity_log_sub_types

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_log_sub_types
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: activity_log_sub_types
- **Source Script**: `04-migration-scripts/master/activity_log_sub_types_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_log_sub_types`
- **New Path**: `smac_master_migration.crewing.activity_log_sub_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Activity Log Sub Types (`seafarer_activity_log_sub_types` → `activity_log_sub_types`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `code` generated from `name` via `generate_meaningful_code()` — no code column in SAC
- `status` derived from `deleted_at` + `is_active` (Case 3 — `deleted_at` takes precedence)
- `activity_type_id` mapped via `activity_type_id_mapping` from `migration.table_mappings` (source=`seafarer_activity_log_types`)
- Filter: `name IS NOT NULL AND TRIM(name) <> ''`; excludes `'sign on'` / `'sign off'` (case-insensitive)
- `level` set to 0 initially; post-migration UPDATE via `ROW_NUMBER() OVER (ORDER BY name)`
- Second INSERT block for synthetic Sign On/Sign Off rows exists but is commented out

## Special Considerations

- Excludes: Sign On and Sign Off (not migrated; not inserted).
- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.activity_log_sub_types` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `activity_type_id_mapping` | FK lookup | `legacy_activity_type_id`, `target_activity_type_id` | `synergy_seafarer.public.seafarer_activity_log_types` → `?.crewing.activity_log_types` | - |

### `activity_type_id_mapping`

- **Output columns**: legacy_activity_type_id, target_activity_type_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=seafarer_activity_log_types, target_schema=crewing, target_table=activity_log_types

```sql
CREATE TEMP TABLE activity_type_id_mapping AS
SELECT
    tm.source_id::uuid as legacy_activity_type_id,
    tm.target_id as target_activity_type_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'seafarer_activity_log_types'
  AND tm.target_db = current_database()
  AND tm.target_schema = 'crewing'
  AND tm.target_table = 'activity_log_types';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; SAC has no code column; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `COALESCE(TRIM(description), NULL)` | Direct copy; nullable |
| 5 | `—` | — | `level` | numeric | Hardcoded `0`; post-migration UPDATE by `ROW_NUMBER() OVER (ORDER BY name)` | Hierarchy level; recalculated after insert |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `parent_id` | uuid | Hardcoded `'00000000-0000-0000-0000-000000000000'` | SMAC default; no parent in SAC |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `deleted_at, is_active` | timestamp without time zone, boolean | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else map `is_active` boolean to Active (0) / Inactive (2) | Case 3 — `deleted_at` takes precedence |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | No source equivalent |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit user fields NULL | No audit columns in SAC; no `legacy_id` (uuid preserved as `id`) |
| 17 | `—` | — | `tags` | text[] | `NULL` | Not populated from SAC |
| 18 | `activity_log_type_id` | uuid | `activity_type_id` | uuid | Map via `activity_type_id_mapping`; fallback first `activity_log_types` row or zero-UUID | FK lookup: `seafarer_activity_log_types` → `activity_log_types` |

**SAC columns not migrated:** `identifier`, `on_vessel`, `is_medical`, `is_training`, `is_payable`, `is_manual` — not referenced in migration script.

**SMAC columns not migrated:** None beyond defaults above.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Activity Type ID Mapping
**Output columns**: `legacy_activity_type_id, target_activity_type_id`
**migration.table_mappings**: `seafarer_activity_log_types` → `activity_log_types` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE activity_type_id_mapping AS
SELECT
    tm.source_id::uuid as legacy_activity_type_id,
    tm.target_id as target_activity_type_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'seafarer_activity_log_types'
  AND tm.target_db = current_database()
  AND tm.target_schema = 'crewing'
  AND tm.target_table = 'activity_log_types';
```

Full migration context: `04-migration-scripts/master/activity_log_sub_types_migration.sql`

## Validation

- Run `05-validation/master/activity_log_sub_types_validation.sql` if available
- Run `06-rollback/master/activity_log_sub_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
