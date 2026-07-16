# Table Mapping: seafarer_remarks_attachments → seafarer_attachments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_remarks_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_remarks.profile_remark.supporting_documents[]`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Remarks Supporting Documents (`seafarer_remarks` → `seafarer_attachments`)

## Migration Notes

- Migrates supporting_documents from profile_remark JSONB array
- Each supporting document becomes a separate attachment record
- Skips records where supporting_documents is empty array
- Migrates supporting_documents from seafarer_remarks.profile_remark JSONB array to seafarer_attachments. Each supporting document becomes a separate attachment record. Generates new UUIDs for id. Maps seafarer_id (bigint) to uuid via migration.table_mappings. Maps reference_id to seafarer_remarks.id (bigint) to uuid. Sets file_type to 'SEAFARER_REMARK' and file_sub_type to 'SUPPORTING_DOCUMENT'. Sets status to 'ACTIVE'. Skips records where supporting_documents is empty array. Requires seafarers and seafarer_remarks tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_remarks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Clear existing data from target table (only | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_remarks_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Purpose**: Clear existing data from target table (only
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `seafarer_remarks_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=seafarer_remarks

```sql
CREATE TEMP TABLE seafarer_remarks_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_remarks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_remarks'::VARCHAR(100), legacy_data.id::text || '_doc_' || doc.doc_idx::text, cu... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | file_name | - | COALESCE(NULLIF(TRIM(doc.doc->>'file_name'), ''), '') as file_name | COALESCE(NULLIF(TRIM(doc.doc->>'file_name'), ''), '') |
| 4 | derived | - | file_type | - | CASE WHEN doc.doc->>'file_content_type' IS NOT NULL AND doc.doc->>'file_content_type' LIKE '%/%' THEN SPLIT_PART(TRIM(doc.doc->>'file_content_type'), '/', 1) ELSE 'application' ... | CASE WHEN doc.doc->>'file_content_type' IS NOT NULL AND doc.doc->>'file_content_type' LIKE '%/%' THEN SPLIT_PART(TRIM(doc.doc->>'file_content_type'), '/', 1) ELSE 'application' END |
| 5 | derived | - | file_sub_type | - | CASE WHEN doc.doc->>'file_content_type' IS NOT NULL AND doc.doc->>'file_content_type' LIKE '%/%' THEN SPLIT_PART(TRIM(doc.doc->>'file_content_type'), '/', 2) ELSE NULL END as fi... | CASE WHEN doc.doc->>'file_content_type' IS NOT NULL AND doc.doc->>'file_content_type' LIKE '%/%' THEN SPLIT_PART(TRIM(doc.doc->>'file_content_type'), '/', 2) ELSE NULL END |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | derived | - | file_content_type | - | NULLIF(TRIM(doc.doc->>'file_content_type'), '') as file_content_type | NULLIF(TRIM(doc.doc->>'file_content_type'), '') |
| 8 | derived | - | file_size | - | COALESCE((doc.doc->>'file_size')::bigint, 0) as file_size | COALESCE((doc.doc->>'file_size')::bigint, 0) |
| 9 | derived | - | file_url | - | COALESCE(NULLIF(TRIM(doc.doc->>'url'), ''), '') as file_url | COALESCE(NULLIF(TRIM(doc.doc->>'url'), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'seafarer_remarks'::text as reference_entity | 'seafarer_remarks'::text |
| 12 | - | - | reference_id | - | COALESCE(seafarer_remarks_id_mapping.new_id, NULL::uuid) as reference_id | COALESCE(seafarer_remarks_id_mapping.new_id, NULL::uuid) |
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

- `public.seafarer_remarks`
- `public.seafarers`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Clear existing data from target table (only
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Seafarer Remarks ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='seafarer_remarks'`

```sql
CREATE TEMP TABLE seafarer_remarks_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_remarks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_remarks_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_remarks_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_remarks_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
