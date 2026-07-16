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

- Generate new UUID for id (source table has bigint id)
- Map seafarer_id (bigint) → seafarer_id (uuid) via migration.table_mappings
- Calculate completeness_percentage from total_completed/total_required
- Derive section_id (may need lookup or default UUID)
- Uses standardized SMAC audit_info structure
- Migrates seafarer_summaries to seafarer_section_progress table. Generates new UUIDs for id column (source has bigint, target has uuid). Maps seafarer_id (bigint) to uuid via migration.table_mappings. Extracts total_required and total_completed from section_summary JSONB. Calculates completeness_percentage. Derives section_id (generates UUID, may need lookup table). Uses standardized SMAC audit_info structure. Requires seafarers table to be migrated first.

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
| 1 | seafarer_id, section_json, source_array, id | - | id | - | migration.resolve_target_id() | DISTINCT ON (combined_sections.seafarer_id, combined_sections.section_json->>'section_identifier', combined_sections.source_array) migration.resolve_target_id( 'synergy_seafarer... |
| 2 | derived | - | seafarer_id | - | seafarer_mapping.target_id AS seafarer_id | seafarer_mapping.target_id |
| 3 | derived | - | section_id | - | COALESCE( section_mapping.section_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS section_id | COALESCE( section_mapping.section_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | section_json | - | total_required | - | COALESCE( (combined_sections.section_json->>'mandatory_fields_count')::integer, 0 ) AS total_required | COALESCE( (combined_sections.section_json->>'mandatory_fields_count')::integer, 0 ) |
| 5 | section_json | - | total_completed | - | COALESCE( (combined_sections.section_json->>'completed_fields_count')::integer, 0 ) AS total_completed | COALESCE( (combined_sections.section_json->>'completed_fields_count')::integer, 0 ) |
| 6 | section_json | - | completeness_percentage | - | CASE WHEN COALESCE((combined_sections.section_json->>'mandatory_fields_count')::integer, 0) > 0 THEN ROUND( (COALESCE((combined_sections.section_json->>'completed_fields_count')... | CASE WHEN COALESCE((combined_sections.section_json->>'mandatory_fields_count')::integer, 0) > 0 THEN ROUND( (COALESCE((combined_sections.section_json->>'completed_fields_count')... |
| 7 | section_json | - | is_complete | - | COALESCE( (combined_sections.section_json->>'is_complete')::boolean, false ) AS is_complete | COALESCE( (combined_sections.section_json->>'is_complete')::boolean, false ) |
| 8 | updated_at, created_at | - | last_validated_at | - | COALESCE( combined_sections.updated_at, combined_sections.created_at, NOW() ) AS last_validated_at | COALESCE( combined_sections.updated_at, combined_sections.created_at, NOW() ) |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | created_at | - | created_at | - | COALESCE(combined_sections.created_at, NOW()) AS created_at | COALESCE(combined_sections.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(combined_sections.updated_at, NOW()) AS updated_at | COALESCE(combined_sections.updated_at, NOW()) |
| 12 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 13 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 14 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN combined_sections.created_by_id IS NOT NULL AND combined_sections.created_by_id::text <> '' THEN combined_sections.created_by_id::text ELSE... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
