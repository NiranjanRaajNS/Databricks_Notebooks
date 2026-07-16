# Table Mapping: dg_sign_on_sign_offs → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: dg_sign_on_sign_offs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_dg_documents_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.dg_sign_on_sign_offs`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debrief Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Extracts file_attachment_ids (JSONB array) from dg_sign_on_sign_offs and joins with dg_file_attachments
- Migrates seafarer_attachments table where entity_type = 'Appraisal_Debrief'. Preserves legacy uuid UUID when available. Maps seafarer_id via seafarers table. Maps reference_id to seafarer_debriefs.id via entity_uuid. Sets reference_entity to 'SeafarerDebrief'. Sets default values for version_number (1) and status (ACTIVE/DELETED). Requires seafarers and seafarer_debriefs tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_debriefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_movements_id_mapping` | FK lookup | `legacy_movement_id`, `movement_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_movements_id_mapping`

- **Output columns**: legacy_movement_id, movement_id
- **migration.table_mappings**: target_table=seafarer_movements

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id::text AS legacy_movement_id,
    target_id AS movement_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_file.id::text) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'dg_file_attachments'::VARCHAR(100), legacy_file.id::te... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_map.seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(seafarer_map.seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | file_name | - | COALESCE(NULLIF(TRIM(legacy_file.original_file_name), ''), 'unnamed_file') AS file_name | COALESCE(NULLIF(TRIM(legacy_file.original_file_name), ''), 'unnamed_file') |
| 4 | derived | - | file_type | - | COALESCE(NULLIF(TRIM(legacy_file.content_type), ''), '') AS file_type | COALESCE(NULLIF(TRIM(legacy_file.content_type), ''), '') |
| 5 | derived | - | file_sub_type | - | 'DgSignOnSignOff' AS file_sub_type | 'DgSignOnSignOff' |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | - | - | file_content_type | - | NULL | NULL::text |
| 8 | derived | - | file_size | - | CAST(COALESCE(legacy_file.content_size, 0) AS bigint) AS file_size | CAST(COALESCE(legacy_file.content_size, 0) AS bigint) |
| 9 | derived | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_file.file_path), ''), '') AS file_url | COALESCE(NULLIF(TRIM(legacy_file.file_path), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'SeafarerMovement' AS reference_entity | 'SeafarerMovement' |
| 12 | derived | - | reference_id | - | movement_map.movement_id AS reference_id | movement_map.movement_id |
| 13 | derived | - | version_number | - | 1 AS version_number | 1 |
| 14 | - | - | valid_from | - | NULL | NULL::date AS valid_ |
| 15 | - | - | valid_until | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | tenant_id | - | See source script | See source script |
| 18 | - | - | created_at | - | See source script | See source script |
| 19 | - | - | updated_at | - | See source script | See source script |
| 20 | - | - | archived_at | - | See source script | See source script |
| 21 | - | - | deleted_at | - | See source script | See source script |
| 22 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_movements`
- `shore.seafarer_movements`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Movements ID Mapping
**Output columns**: `legacy_movement_id, movement_id`
**migration.table_mappings**: `target_table='seafarer_movements'`

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id::text AS legacy_movement_id,
    target_id AS movement_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_dg_documents_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_dg_documents_validation.sql` if available
- Run `06-rollback/crewing/seafarer_dg_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
