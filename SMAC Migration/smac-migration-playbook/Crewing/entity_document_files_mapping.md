# Table Mapping: seafarer_signoff_documents → entity_document_files

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: entity_document_files
- **Source Script**: `04-migration-scripts/crewing/entity_document_files_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_documents`
- **New Path**: `smac_crewing_migration.public.entity_document_files`

## Business Key

- **Composite Key**: (`entity_document_id`, `file_name`)
- **Source (orchestration)**: Entity Document Files (`seafarer_signoff_documents` → `entity_document_files`)

## Migration Notes

- Migrates seafarer_signoff_documents to entity_document_files. Generates new UUID for id. Maps mapper_uuid to entity_document_id via entity_documents mapping. One file record per seafarer_signoff_documents record.

## Special Considerations

- Script performs `TRUNCATE TABLE public.entity_document_files` before insert (full table reload).
- Orchestration dependencies: `entity_documents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `entity_document_id_mapping` | FK lookup | `legacy_mapper_uuid`, `entity_document_id` | `migration.table_mappings` (see SQL) | - |

### `entity_document_id_mapping`

- **Output columns**: legacy_mapper_uuid, entity_document_id
- **migration.table_mappings**: target_table=entity_documents

```sql
CREATE TEMP TABLE entity_document_id_mapping AS
SELECT
    source_id::text AS legacy_mapper_uuid,
    target_id AS entity_document_id
FROM migration.table_mappings
WHERE target_table = 'entity_documents'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_signoff_documents'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | entity_document_id | - | entity_doc_map.entity_document_id | entity_doc_map.entity_document_id |
| 3 | file_name | - | file_name | - | TRIM(legacy_data.file_name) AS file_name | TRIM(legacy_data.file_name) |
| 4 | content_type | - | file_content_type | - | TRIM(legacy_data.content_type) AS file_content_type | TRIM(legacy_data.content_type) |
| 5 | content_size | - | file_size | - | legacy_data.content_size AS file_size | legacy_data.content_size |
| 6 | url | - | file_url | - | TRIM(legacy_data.url) AS file_url | TRIM(legacy_data.url) |
| 7 | - | - | checksum | - | NULL | NULL::text |
| 8 | derived | - | version_number | - | 1 AS version_number | 1 |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | - | - | archived_at | - | NULL | NULL::timestamp |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 15 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Entity Document ID Mapping
**Output columns**: `legacy_mapper_uuid, entity_document_id`
**migration.table_mappings**: `target_table='entity_documents'`

```sql
CREATE TEMP TABLE entity_document_id_mapping AS
SELECT
    source_id::text AS legacy_mapper_uuid,
    target_id AS entity_document_id
FROM migration.table_mappings
WHERE target_table = 'entity_documents'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/entity_document_files_migration.sql`

## Validation

- Run `05-validation/crewing/entity_document_files_validation.sql` if available
- Run `06-rollback/crewing/entity_document_files_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
