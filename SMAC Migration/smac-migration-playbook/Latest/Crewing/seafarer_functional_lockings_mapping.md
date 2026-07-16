# Table Mapping: seafarer_functional_lockings → seafarer_functional_lockings

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_functional_lockings
- **New Database**: smac_master_migration
- **New Schema**: shore
- **New Table**: seafarer_functional_lockings
- **Source Script**: `04-migration-scripts/crewing/seafarer_functional_lockings_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_functional_lockings`
- **New Path**: `smac_master_migration.shore.seafarer_functional_lockings`

## Business Key

- **Composite Key**: (`seafarer_id`, `id`)
- **Source (orchestration)**: Seafarer Functional Lockings (`seafarer_functional_lockings` → `seafarer_functional_lockings`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `seafarer_id` via `seafarer_id_mapping` (`table_mappings` where `target_table = 'seafarers'`); nil UUID if unmapped
- `created_by` / `updated_by` parsed as uuid only when valid UUID format; else `NULL`
- `stage_code` not in SAC — set to `NULL`
- `payload` direct copy with `'{}'::jsonb` fallback (NOT NULL)
- `archived_at`, `deleted_at` set to `NULL` (not in SAC source)
- Uses `migration.build_audit_info()` with created/updated by names in `notes`
- Requires `seafarers` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_functional_lockings` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC `id` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` where `target_table = 'seafarers'` |
| 3 | — | — | `stage_code` | character varying(50) | `NULL` | No equivalent in SAC; not populated |
| 4 | `payload` | jsonb | `payload` | jsonb | `COALESCE(payload, '{}'::jsonb)` | NOT NULL in SMAC; empty object when NULL |
| 5 | `created_by_id` | text | `created_by` | uuid | Cast to uuid when valid UUID format; else `NULL` | SMAC column separate from `audit_info` |
| 6 | `updated_by_id` | text | `updated_by` | uuid | Cast to uuid when valid UUID format; else `NULL` | SMAC column separate from `audit_info` |
| 7 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 8 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 9 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 10 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 11 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 12 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` — names combined into `notes` | No `legacy_id` (uuid preserved as `id`) |

**SMAC columns not migrated:** None beyond explicit NULLs above.

**SAC columns not migrated:** None — all SAC columns in SELECT are mapped or used in audit.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_functional_lockings_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_functional_lockings_validation.sql` if available
- Run `06-rollback/crewing/seafarer_functional_lockings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
