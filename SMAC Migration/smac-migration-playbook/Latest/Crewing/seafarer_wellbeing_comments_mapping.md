# Table Mapping: seafarer_wellbeing_comments → seafarer_wellbeing_comments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_wellbeing_comments
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_wellbeing_comments
- **Source Script**: `04-migration-scripts/crewing/seafarer_wellbeing_comments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_wellbeing_comments`
- **New Path**: `smac_crewing_migration.shore.seafarer_wellbeing_comments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Wellbeing Comments (`seafarer_wellbeing_comments` → `seafarer_wellbeing_comments`, group: SeafarerWellbeing)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`; duplicate UUID check
- `wellbeing_id` mapped via `wellbeing_id_mapping`; fallback legacy UUID
- Filter: `id IS NOT NULL AND wellbeing_id IS NOT NULL`
- Requires `seafarer_wellbeing` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_wellbeing_comments` before insert (full table reload).
- Orchestration dependencies: `seafarer_wellbeing`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `wellbeing_id_mapping` | FK lookup | `legacy_id`, `new_id` | `synergy_seafarer.public.seafarer_wellbeing` → `smac_crewing_migration.shore.seafarer_wellbeing` | - |

### `wellbeing_id_mapping`

- **Purpose**: FK lookup for wellbeing parent records
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=seafarer_wellbeing, target_schema=shore, target_table=seafarer_wellbeing

```sql
CREATE TEMP TABLE wellbeing_id_mapping AS
SELECT
    source_id::uuid AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_db = current_database()
  AND target_schema = 'shore'
  AND target_table = 'seafarer_wellbeing'
  AND source_db = 'synergy_seafarer'
  AND source_schema = 'public'
  AND source_table = 'seafarer_wellbeing'
  AND source_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `wellbeing_id` | uuid | `wellbeing_id` | uuid | Map via `wellbeing_id_mapping`; fallback legacy UUID | |
| 3 | `comment_text` | text | `comment_text` | text | Direct copy | |
| 4 | `comment_type` | character varying | `comment_type` | text | `COALESCE(comment_type, '')` | |
| 5 | `deleted_by_id` | character varying | `deleted_by_id` | uuid | UUID regex cast | |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 9 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 11 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — UUID regex for IDs; names in `notes` | Standardized SMAC audit structure; no `legacy_id` (UUID preserved as `id`) |

**SMAC columns not migrated:** `archived_at` — always NULL.

**SAC columns not migrated:** None in dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_wellbeing`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Wellbeing ID Mapping
**Purpose**: FK lookup for wellbeing parent records
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `seafarer_wellbeing` → `seafarer_wellbeing` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE wellbeing_id_mapping AS
SELECT
    source_id::uuid AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_db = current_database()
  AND target_schema = 'shore'
  AND target_table = 'seafarer_wellbeing'
  AND source_db = 'synergy_seafarer'
  AND source_schema = 'public'
  AND source_table = 'seafarer_wellbeing'
  AND source_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_wellbeing_comments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_wellbeing_comments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_wellbeing_comments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
