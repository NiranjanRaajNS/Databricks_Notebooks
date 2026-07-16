# Table Mapping: cba_nationalities → cba_nationalities

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_nationalities
- **Source Script**: `04-migration-scripts/master/cba_nationalities_migration.sql`

- **Legacy Path**: `synergy_master.public.cbas.nationality (JSONB)`
- **New Path**: `smac_master_migration.crewing.cba_nationalities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Nationalities (`nationalities` → `nationalities`)

## Migration Notes

- Unpivots `cbas.nationality` JSONB array into one row per nationality
- Composite source_id: `cba_id || '_' || nationality_text`
- Skips `['ALL']` arrays (handled by `cbas.is_all_nationalities`)
- Requires resolvable `cba_id` and `nationality` (via `nationalities.code`)

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.cba_nationalities` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `nationalities_id_mapping` | Check if any mappings already | `normalized_code`, `nationality_id` | - | - |

### `cbas_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=crewing, target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_schema = 'crewing'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `nationalities_id_mapping`

- **Purpose**: Check if any mappings already
- **Output columns**: normalized_code, nationality_id

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, nationality` | bigint, jsonb | `id` | uuid | `migration.resolve_target_id()` — composite `cba_id || '_' || nationality_text`; `p_target_id = NULL` | One row per nationality element |
| 2 | `id` | bigint | `cba_id` | uuid | Map via `cbas_id_mapping` | FK: migrated `cbas` |
| 3 | `nationality` | jsonb | `nationality` | uuid | Match `nationality_text` to `nationalities.code` (UPPER) | FK: `nationalities` |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 8 | `deleted_at` | timestamp without time zone | `status` | integer | Parent `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | From parent CBA row |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | From parent CBA row |  |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | From parent CBA row |  |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | From parent CBA row |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** Individual nationality values when array is `['ALL']` — handled by `cbas.is_all_nationalities`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`
- `crewing.cbas`
- `public.nationalities`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cbas ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cbas'`

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_schema = 'crewing'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Nationalities ID Mapping
**Purpose**: Check if any mappings already
**Output columns**: `normalized_code, nationality_id`

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

Full migration context: `04-migration-scripts/master/cba_nationalities_migration.sql`

## Validation

- Run `05-validation/master/cba_nationalities_validation.sql` if available
- Run `06-rollback/master/cba_nationalities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
