# Table Mapping: seafarer_summaries → seafarer_section_progress

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_summaries
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_section_progress
- **Source Script**: `04-migration-scripts/crewing/seafarer_section_progress_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_summaries`
- **New Path**: `smac_crewing_migration.shore.seafarer_section_progress`

## Business Key

- **Composite Key**: (`seafarer_id`, `section_id`)
- **Source (orchestration)**: Seafarer Section Progress (`seafarer_summaries` → `seafarer_section_progress`)

## Migration Notes

- Source `seafarer_summaries` — one SAC row expands to many SMAC rows via `UNION ALL` over 4 JSONB arrays
- `id` via `migration.resolve_target_id()` with composite key from `id`, `section_identifier`, `source_array`
- `seafarer_id` (bigint) → uuid via `seafarer_id_mapping`; rows without mapping skipped
- `section_id` resolved from unnested `section_identifier` via `seafarer_sections_mapping` (Title Case name match; `other_details` → `important_declarations`)
- `completeness_percentage` calculated from `total_completed / total_required`
- `DISTINCT ON (seafarer_id, section_identifier, source_array)` deduplication
- Uses `migration.build_audit_info()` with created/updated by names in `notes`
- Requires `seafarers` and `crewing.seafarer_sections` (master) migrated first

## Special Considerations

- Extract total_required and total_completed from section_summary JSONB
- Script performs `TRUNCATE TABLE shore.seafarer_section_progress` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_sections_mapping` | FK lookup | `section_id`, `name_lower`, `name_original`, `section_code` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `seafarer_sections_mapping`

- **Output columns**: section_id, name_lower, name_original, section_code
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_sections_mapping AS
SELECT
    id AS section_id,
    LOWER(TRIM(name)) AS name_lower,
    name AS name_original,
    code AS section_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM crewing.seafarer_sections'
) AS t(id uuid, name text, code text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `section_identifier`, `source_array` | bigint, text, text | `id` | uuid | `migration.resolve_target_id()` — composite source_id from `id`, `section_identifier`, `source_array` | Idempotent; one UUID per unnested section row |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping` | Required; unmapped rows skipped |
| 3 | `section_json.section_identifier` | text (JSON) | `section_id` | uuid | Join `seafarer_sections_mapping` on Title Case name; default nil UUID | Lookup: `crewing.seafarer_sections` via dblink |
| 4 | `section_json.mandatory_fields_count` | text (JSON) | `total_required` | integer | `COALESCE(...::integer, 0)` | From unnested array element |
| 5 | `section_json.completed_fields_count` | text (JSON) | `total_completed` | integer | `COALESCE(...::integer, 0)` | From unnested array element |
| 6 | - | — | `completeness_percentage` | numeric | `(total_completed / total_required) * 100` or `0` | Calculated when `total_required > 0` |
| 7 | `section_json.is_complete` | text (JSON) | `is_complete` | boolean | `COALESCE(...::boolean, false)` | From unnested array element |
| 8 | `updated_at`, `created_at` | timestamp without time zone | `last_validated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 13 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at` on summaries |
| 14 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | - |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** Parent JSONB arrays (`section_summary`, `authentication_summary`, `internal_document_summary`, `expiring_document_summary`) — only unnested elements migrated.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Seafarer Sections ID Mapping
**Output columns**: `section_id, name_lower, name_original, section_code`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_sections_mapping AS
SELECT
    id AS section_id,
    LOWER(TRIM(name)) AS name_lower,
    name AS name_original,
    code AS section_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM crewing.seafarer_sections'
) AS t(id uuid, name text, code text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_section_progress_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_section_progress_validation.sql` if available
- Run `06-rollback/crewing/seafarer_section_progress_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
