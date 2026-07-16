# Table Mapping: seafarer_joining_documents → seafarer_joining_documents

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_joining_documents
- **Source Script**: `04-migration-scripts/crewing/seafarer_joining_documents_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Joining Documents (`seafarer_documents` → `seafarer_documents`)

## Migration Notes

- Uses joining_document_summary table (pre-joined with relief_summary & assignments)
- No complex seafarer ID mapping needed (smac_seafarer_id already UUID)
- No assignment lookups needed (assignment_id already resolved)
- Simplified data flow, faster execution
- All form_response JSON transformations (Cases 560-667)
- Helper function extract_survey_answer()
- Status mapping logic (progress_status_id, record status)
- UUID validations and audit_info structure
- Processes records in batches of 5000
- Provides progress logging for each batch
- Single transaction with rollback on error
- Form response transformations done at summary table level (formio_response column)
- Maps joining documents (document_group_id = 96) from synergy_seafarer.public.seafarer_documents to public.seafarer_documents. Preserves legacy uuid column as target id (Pattern 4). Append-only migration. Maps seafarer_id from bigint to UUID via migration.table_mappings. Maps document_id from joining document type (fdc23dd0-d06d-4107-a65c-bf14583175f3). Sets document_parts_id to NULL (joining documents don't have parts). Maps status from integer to text. Requires seafarers and documents tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `documents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `document_sub_category_to_document_mapping` | FK lookup | `sub_category_id`, `sub_category_code`, `sub_category_name`, `document_id`, `document_code`, `document_name`, `document_status`, `document_type_id` | - | - |
| `document_devation_reasons_id_mapping` | ====================== | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `document_progress_status_lookup` | Delete assignment documents FIRST (avoid duplicates / FK const | `dps.id`, `dps.code`, `dps.name`, `normalized_code`, `normalized_name` | - | `smac_master_migration` |
| `temp_seafarer_documents_id_map` | FK lookup | `source_id_key`, `tm.target_id` | `synergy_seafarer.document.seafarer_documents` → `?.public.seafarer_documents` | - |
| `temp_joining_document_files_id_map` | FK lookup | `source_id_key`, `tm.target_id` | `synergy_seafarer.public.document_files` → `?.public.seafarer_document_files` | - |

### `document_sub_category_to_document_mapping`

- **Output columns**: sub_category_id, sub_category_code, sub_category_name, document_id, document_code, document_name, document_status, document_type_id

```sql
CREATE TEMP TABLE document_sub_category_to_document_mapping AS
SELECT
    ldsc.id as sub_category_id,
    ldsc.code as sub_category_code,
    ldsc.name as sub_category_name,
    mjd.id as document_id,
    mjd.code as document_code,
    mjd.name as document_name,
    mjd.status as document_status,
    mjd.document_type_id as document_type_id
FROM legacy_document_sub_categories ldsc
LEFT JOIN master_joining_documents mjd ON LOWER(TRIM(ldsc.code)) = LOWER(TRIM(mjd.code));
```

### `document_devation_reasons_id_mapping`

- **Purpose**: ======================
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE document_devation_reasons_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''document_devation_reasons'''
) AS t(source_id text, target_id uuid);
```

### `document_progress_status_lookup`

- **Purpose**: Delete assignment documents FIRST (avoid duplicates / FK const
- **Output columns**: dps.id, dps.code, dps.name, normalized_code, normalized_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE document_progress_status_lookup AS
SELECT
    dps.id,
    dps.code,
    dps.name,
    UPPER(TRIM(COALESCE(dps.code, ''))) as normalized_code,
    UPPER(TRIM(COALESCE(dps.name, ''))) as normalized_name
FROM dblink('smac_master_migration',
    'SELECT id, code, name FROM document.document_progress_status WHERE id IS NOT NULL'
) AS dps(id uuid, code text, name text)
WHERE dps.id IS NOT NULL;
```

### `temp_seafarer_documents_id_map`

- **Output columns**: source_id_key, tm.target_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=document, source_table=seafarer_documents, target_schema=public, target_table=seafarer_documents

```sql
CREATE TEMP TABLE temp_seafarer_documents_id_map AS
SELECT DISTINCT ON (LEFT(tm.source_id, 100))
    LEFT(tm.source_id, 100) AS source_id_key,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'document'
  AND tm.source_table = 'seafarer_documents'
  AND tm.target_db = current_database()::text
  AND tm.target_schema = 'public'
  AND tm.target_table = 'seafarer_documents'
ORDER BY LEFT(tm.source_id, 100), tm.migrated_at DESC NULLS LAST;
```

### `temp_joining_document_files_id_map`

- **Output columns**: source_id_key, tm.target_id
- **migration.table_mappings**: source_db=synergy_seafarer, source_schema=public, source_table=document_files, target_schema=public, target_table=seafarer_document_files

```sql
CREATE TEMP TABLE temp_joining_document_files_id_map AS
SELECT DISTINCT ON (LEFT(tm.source_id, 100))
    LEFT(tm.source_id, 100) AS source_id_key,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'document_files'
  AND tm.target_db = current_database()::text
  AND tm.target_schema = 'public'
  AND tm.target_table = 'seafarer_document_files'
ORDER BY LEFT(tm.source_id, 100), tm.migrated_at DESC NULLS LAST;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | uuid | - | id | - | COALESCE(doc_id_map.target_id, jds.uuid) AS id | COALESCE(doc_id_map.target_id, jds.uuid) |
| 2 | smac_seafarer_id | - | seafarer_id | - | COALESCE(jds.smac_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(jds.smac_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | document_id | - | COALESCE(document_sub_category_uuid,'00000000-0000-0000-0000-000000000000'::uuid) AS document_id | COALESCE(document_sub_category_uuid,'00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | document_parts_id | - | NULL AS document_parts_id | NULL |
| 5 | derived | - | reference_number | - | NULLIF(TRIM(jds."number"), '') AS reference_number | NULLIF(TRIM(jds."number"), '') |
| 6 | issue_date | - | issue_date | - | CASE WHEN jds.issue_date IS NOT NULL THEN jds.issue_date::date ELSE NULL END AS issue_date | CASE WHEN jds.issue_date IS NOT NULL THEN jds.issue_date::date ELSE NULL END |
| 7 | expiry_date | - | expiry_date | - | CASE WHEN jds.expiry_date IS NOT NULL THEN jds.expiry_date::date ELSE NULL END AS expiry_date | CASE WHEN jds.expiry_date IS NOT NULL THEN jds.expiry_date::date ELSE NULL END |
| 8 | issuing_authority | - | issuing_authority | - | NULLIF(TRIM(jds.issuing_authority), '') AS issuing_authority | NULLIF(TRIM(jds.issuing_authority), '') |
| 9 | place_of_issue | - | place_of_issue | - | NULLIF(TRIM(jds.place_of_issue), '') AS place_of_issue | NULLIF(TRIM(jds.place_of_issue), '') |
| 10 | remark | - | remarks | - | NULLIF(TRIM(jds.remark), '') AS remarks | NULLIF(TRIM(jds.remark), '') |
| 11 | attachment_status | - | has_document | - | CASE WHEN jds.attachment_status IS NOT NULL AND jds.attachment_status > 0 THEN true ELSE false END AS has_document | CASE WHEN jds.attachment_status IS NOT NULL AND jds.attachment_status > 0 THEN true ELSE false END |
| 12 | - | - | no_document_reason | - | NULL | NULL::text |
| 13 | derived | - | version | - | 1 AS version | 1 |
| 14 | bypass_status | - | bypass_status | - | CASE WHEN jds.bypass_status IS NOT NULL THEN jds.bypass_status::text ELSE NULL END AS bypass_status | CASE WHEN jds.bypass_status IS NOT NULL THEN jds.bypass_status::text ELSE NULL END |
| 15 | derived | - | bypass_reason_id | - | ddr_mapping.new_id AS bypass_reason_id | ddr_mapping.new_id |
| 16 | bypass_by | - | bypass_by_id | - | CASE WHEN jds.bypass_by IS NOT NULL AND jds.bypass_by::text != '{}' AND jds.bypass_by ? 'VerifiedById' AND (jds.bypass_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{... | CASE WHEN jds.bypass_by IS NOT NULL AND jds.bypass_by::text != '{}' AND jds.bypass_by ? 'VerifiedById' AND (jds.bypass_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{... |
| 17 | deviate_note | - | bypass_reason | - | NULLIF(TRIM(jds.deviate_note), '') AS bypass_reason | NULLIF(TRIM(jds.deviate_note), '') |
| 18 | derived | - | has_attachments | - | false AS has_attachments | false |
| 19 | formio_response | - | form_response | - | jds.formio_response AS form_response | jds.formio_response |
| 20 | - | - | supporting_documents | - | NULL | NULL::jsonb |
| 21 | - | - | metadata | - | NULL | NULL::jsonb |
| 22 | derived | - | workflow_status_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS workflow_status_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 23 | status | - | progress_status_id | - | COALESCE( (SELECT id FROM document_progress_status_lookup WHERE normalized_code = CASE WHEN jds.status = 0 THEN 'UNVERIFIED' WHEN jds.status = 1 THEN 'VERIFIED' WHEN jds.status ... | COALESCE( (SELECT id FROM document_progress_status_lookup WHERE normalized_code = CASE WHEN jds.status = 0 THEN 'UNVERIFIED' WHEN jds.status = 1 THEN 'VERIFIED' WHEN jds.status ... |
| 24 | verified_date | - | verified_at | - | CASE WHEN jds.verified_date IS NOT NULL THEN jds.verified_date::timestamp ELSE NULL END AS verified_at | CASE WHEN jds.verified_date IS NOT NULL THEN jds.verified_date::timestamp ELSE NULL END |
| 25 | verified_by_id | - | verified_by_id | - | CASE WHEN jds.verified_by_id IS NOT NULL AND jds.verified_by_id::text != '' AND (jds.verified_by_id) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (jds... | CASE WHEN jds.verified_by_id IS NOT NULL AND jds.verified_by_id::text != '' AND (jds.verified_by_id) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (jds... |
| 26 | approval_comment | - | verification_notes | - | jds.approval_comment AS verification_notes | jds.approval_comment |
| 27 | - | - | approved_by_id | - | NULL | NULL::uuid |
| 28 | verified_date | - | approved_at | - | COALESCE(jds.verified_date, NULL::timestamp) AS approved_at | COALESCE(jds.verified_date, NULL::timestamp) |
| 29 | approval_comment | - | approval_notes | - | NULLIF(TRIM(jds.approval_comment), '') AS approval_notes | NULLIF(TRIM(jds.approval_comment), '') |
| 30 | status | - | status | - | CASE WHEN jds.status = 0 THEN 'Active'::text WHEN jds.status = 1 THEN 'Active'::text WHEN jds.status = 2 THEN 'Inactive'::text WHEN jds.status = 3 THEN 'Deleted'::text WHEN jds.... | CASE WHEN jds.status = 0 THEN 'Active'::text WHEN jds.status = 1 THEN 'Active'::text WHEN jds.status = 2 THEN 'Inactive'::text WHEN jds.status = 3 THEN 'Deleted'::text WHEN jds.... |
| 31 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 32 | created_at | - | created_at | - | COALESCE(jds.created_at, NOW()) AS created_at | COALESCE(jds.created_at, NOW()) |
| 33 | updated_at | - | updated_at | - | COALESCE(jds.updated_at, NOW()) AS updated_at | COALESCE(jds.updated_at, NOW()) |
| 34 | - | - | archived_at | - | NULL | NULL::timestamp |
| 35 | deleted_at | - | deleted_at | - | jds.deleted_at AS deleted_at | jds.deleted_at |
| 36 | created_by_id, updated_by_id, seafarer_doc_id, coe_issue_date, coe_expiry_date, cra_issue_date, cra_expiry_date, country_id, visa_class, blockchain_status, mandatory_value, is_confirmed, document_source_id, re_try_count | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN jds.created_by_id IS NOT NULL AND jds.created_by_id::text <> '' THEN jds.created_by_id::text ELSE NULL END, 'deleted_by', NULL, 'upda... | jsonb_build_object( 'created_by', CASE WHEN jds.created_by_id IS NOT NULL AND jds.created_by_id::text <> '' THEN jds.created_by_id::text ELSE NULL END, 'deleted_by', NULL, 'upda... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Document Sub Category To Document ID Mapping
**Output columns**: `sub_category_id, sub_category_code, sub_category_name, document_id, document_code, document_name, document_status, document_type_id`

```sql
CREATE TEMP TABLE document_sub_category_to_document_mapping AS
SELECT
    ldsc.id as sub_category_id,
    ldsc.code as sub_category_code,
    ldsc.name as sub_category_name,
    mjd.id as document_id,
    mjd.code as document_code,
    mjd.name as document_name,
    mjd.status as document_status,
    mjd.document_type_id as document_type_id
FROM legacy_document_sub_categories ldsc
LEFT JOIN master_joining_documents mjd ON LOWER(TRIM(ldsc.code)) = LOWER(TRIM(mjd.code));
```

### 2. Document Devation Reasons ID Mapping
**Purpose**: ======================
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE document_devation_reasons_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''document_devation_reasons'''
) AS t(source_id text, target_id uuid);
```

### 3. Document Progress Status ID Mapping
**Purpose**: Delete assignment documents FIRST (avoid duplicates / FK const
**Output columns**: `dps.id, dps.code, dps.name, normalized_code, normalized_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE document_progress_status_lookup AS
SELECT
    dps.id,
    dps.code,
    dps.name,
    UPPER(TRIM(COALESCE(dps.code, ''))) as normalized_code,
    UPPER(TRIM(COALESCE(dps.name, ''))) as normalized_name
FROM dblink('smac_master_migration',
    'SELECT id, code, name FROM document.document_progress_status WHERE id IS NOT NULL'
) AS dps(id uuid, code text, name text)
WHERE dps.id IS NOT NULL;
```

### 4. Temp Seafarer Documents ID Mapping
**Output columns**: `source_id_key, tm.target_id`
**migration.table_mappings**: `seafarer_documents` → `seafarer_documents` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE temp_seafarer_documents_id_map AS
SELECT DISTINCT ON (LEFT(tm.source_id, 100))
    LEFT(tm.source_id, 100) AS source_id_key,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'document'
  AND tm.source_table = 'seafarer_documents'
  AND tm.target_db = current_database()::text
  AND tm.target_schema = 'public'
  AND tm.target_table = 'seafarer_documents'
ORDER BY LEFT(tm.source_id, 100), tm.migrated_at DESC NULLS LAST;
```

### 5. Temp Joining Document Files ID Mapping
**Output columns**: `source_id_key, tm.target_id`
**migration.table_mappings**: `document_files` → `seafarer_document_files` (source_db=`synergy_seafarer`)

```sql
CREATE TEMP TABLE temp_joining_document_files_id_map AS
SELECT DISTINCT ON (LEFT(tm.source_id, 100))
    LEFT(tm.source_id, 100) AS source_id_key,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.source_db = 'synergy_seafarer'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'document_files'
  AND tm.target_db = current_database()::text
  AND tm.target_schema = 'public'
  AND tm.target_table = 'seafarer_document_files'
ORDER BY LEFT(tm.source_id, 100), tm.migrated_at DESC NULLS LAST;
```

Full migration context: `04-migration-scripts/crewing/seafarer_joining_documents_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_joining_documents_validation.sql` if available
- Run `06-rollback/crewing/seafarer_joining_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
