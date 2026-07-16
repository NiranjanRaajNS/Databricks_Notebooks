# Table Mapping: seafarer_movements_attachments → seafarer_attachments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_movements_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.dg_sign_on_sign_offs.file_attachment_ids[]`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Movements Attachments (`dg_sign_on_sign_offs` → `seafarer_attachments`)

## Migration Notes

- Migrates file_attachment_ids from dg_sign_on_sign_offs JSONB array
- Each file_attachment_id references dg_file_attachments table
- Each attachment becomes a separate seafarer_attachments record
- Skips records where file_attachment_ids is empty array
- Migrates file_attachment_ids from dg_sign_on_sign_offs.file_attachment_ids JSONB array to seafarer_attachments. Each file_attachment_id references dg_file_attachments table. Each attachment becomes a separate seafarer_attachments record. Uses resolve_target_id for id generation. Maps seafarer_uuid (uuid) to seafarer_id (uuid) via seafarers table. Maps reference_id to seafarer_movements.id (uuid) via migration.table_mappings from dg_sign_on_sign_offs.id. Sets reference_entity to 'seafarer_movements'. Derives file_type and file_sub_type from content_type by splitting on '/'. Sets status to 'ACTIVE' or 'DELETED' based on deleted_at. Skips records where file_attachment_ids is empty array. Requires seafarers and seafarer_movements tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_movements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `target_id`, `seafarer_uuid_text` | - | - |
| `seafarer_movements_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_uuid_mapping`

- **Output columns**: target_id, seafarer_uuid_text

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

### `seafarer_movements_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=seafarer_movements

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'dg_file_attachments'::VARCHAR(100), dg_file.id::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_uuid_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_uuid_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | file_name | - | COALESCE(NULLIF(TRIM(dg_file.original_file_name), ''), '') as file_name | COALESCE(NULLIF(TRIM(dg_file.original_file_name), ''), '') |
| 4 | derived | - | file_type | - | CASE WHEN dg_file.content_type IS NOT NULL AND dg_file.content_type LIKE '%/%' THEN SPLIT_PART(TRIM(dg_file.content_type), '/', 1) ELSE 'application' END as file_type | CASE WHEN dg_file.content_type IS NOT NULL AND dg_file.content_type LIKE '%/%' THEN SPLIT_PART(TRIM(dg_file.content_type), '/', 1) ELSE 'application' END |
| 5 | derived | - | file_sub_type | - | CASE WHEN dg_file.content_type IS NOT NULL AND dg_file.content_type LIKE '%/%' THEN SPLIT_PART(TRIM(dg_file.content_type), '/', 2) ELSE NULL END as file_sub_type | CASE WHEN dg_file.content_type IS NOT NULL AND dg_file.content_type LIKE '%/%' THEN SPLIT_PART(TRIM(dg_file.content_type), '/', 2) ELSE NULL END |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | derived | - | file_content_type | - | NULLIF(TRIM(dg_file.content_type), '') as file_content_type | NULLIF(TRIM(dg_file.content_type), '') |
| 8 | derived | - | file_size | - | COALESCE( CASE WHEN dg_file.content_size ~ '^[0-9]+$' THEN (dg_file.content_size)::bigint ELSE 0 END, 0 ) as file_size | COALESCE( CASE WHEN dg_file.content_size ~ '^[0-9]+$' THEN (dg_file.content_size)::bigint ELSE 0 END, 0 ) |
| 9 | derived | - | file_url | - | COALESCE(NULLIF(TRIM(dg_file.file_path), ''), '') as file_url | COALESCE(NULLIF(TRIM(dg_file.file_path), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'seafarer_movements'::text as reference_entity | 'seafarer_movements'::text |
| 12 | - | - | reference_id | - | COALESCE(seafarer_movements_id_mapping.new_id, NULL::uuid) as reference_id | COALESCE(seafarer_movements_id_mapping.new_id, NULL::uuid) |
| 13 | derived | - | version_number | - | 1 as version_number | 1 |
| 14 | - | - | valid_from | - | NULL | NULL::date as valid_ |
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

- `public.seafarers`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `target_id, seafarer_uuid_text`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

### 2. Seafarer Movements ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='seafarer_movements'`

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_movements_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_movements_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_movements_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
