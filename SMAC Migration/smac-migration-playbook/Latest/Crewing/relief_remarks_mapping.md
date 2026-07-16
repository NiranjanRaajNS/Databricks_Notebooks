# Table Mapping: reliefs → relief_remarks

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: reliefs
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: relief_remarks
- **Source Script**: `04-migration-scripts/crewing/relief_remarks_migration.sql`

- **Legacy Path**: `synergy_manning.public.reliefs`
- **New Path**: `smac_crewing_migration.shore.relief_remarks`

## Business Key

- **Business Key**: `relief_id`
- **Source (orchestration)**: Relief Remarks (`reliefs` → `relief_remarks`)

## Migration Notes

- Source is SAC `synergy_manning.reliefs.onsigner_remarks` JSONB array — one SMAC row per array element
- Composite source key: `id::text || '|' || ordinality` via `migration.resolve_target_id()` with `p_target_id = NULL`
- `relief_id` mapped via `relief_id_mapping` (`migration.table_mappings` where `target_table = 'seafarer_reliefs'`); nil UUID if unmapped
- `comment` extracted from unnested JSONB (`comment`/`remarks`/`text`/`note` key variants)
- `created_by_id` (varchar) cast to uuid when valid UUID format; else nil UUID
- `audit_info` via `migration.build_audit_info()` plus `legacy_relief_id` and `legacy_ordinality` metadata
- Only reliefs where `onsigner_remarks` is a non-empty JSONB array are migrated
- Requires `seafarer_reliefs` migrated first

## Special Considerations

- Extract comment from onsigner_remarks JSONB
- Script performs `TRUNCATE TABLE shore.relief_remarks` before insert (full table reload).
- Orchestration dependencies: `seafarer_reliefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relief_id_mapping` | Check if any mappings already exist | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `relief_id_mapping`

- **Purpose**: Check if any mappings already exist
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarer_reliefs

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, array ordinality | bigint, integer | `id` | uuid | `migration.resolve_target_id()` — source_id = `LEFT(id::text \|\| '\|' \|\| ordinality::text, 100)`; `p_target_id = NULL` | Composite key per remark within relief |
| 2 | `id` | bigint | `relief_id` | uuid | Map via `relief_id_mapping` (`target_table = 'seafarer_reliefs'`); default nil UUID | LEFT JOIN — nil UUID when unmapped |
| 3 | `onsigner_remarks` (JSONB) → comment | jsonb | `comment` | text | `COALESCE(->>'comment', ->>'remarks', ->>'text', ->>'note', '')` from unnested element | NOT NULL; empty string fallback |
| 4 | `created_by_id` | character varying | `created_by_id` | uuid | Cast to UUID when valid format; else nil UUID | Relief-level `created_by_id` (not per-array-element) |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From parent relief record |
| 7 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | From parent relief record |
| 8 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 9 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Inherited from parent relief |
| 10 | `created_by_id`, `updated_by_id`, `id`, ordinality | character varying, bigint | `audit_info` | jsonb | `migration.build_audit_info()` \|\| `legacy_relief_id`, `legacy_ordinality` | Standard audit + mapping metadata |

**SMAC columns not migrated:** None — target table has only columns listed above.

**SAC columns not migrated:** `uuid`, `created_by_name`, `updated_by_name` on `reliefs` — not mapped to separate SMAC columns; relief-level audit names not in target schema.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_reliefs`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relief ID Mapping
**Purpose**: Check if any mappings already exist
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarer_reliefs'`

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/relief_remarks_migration.sql`

## Validation

- Run `05-validation/crewing/relief_remarks_validation.sql` if available
- Run `06-rollback/crewing/relief_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
