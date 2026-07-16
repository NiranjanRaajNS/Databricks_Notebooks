# Table Mapping: seafarer_documents → seafarer_documents

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: document
- **Legacy Table**: seafarer_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_documents
- **Source Script**: `04-migration-scripts/crewing/seafarer_documents_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.seafarer_documents`
- **New Path**: `smac_crewing_migration.public.seafarer_documents`

## Migration Notes

- Post-migration update script: For joining documents (SAC public.seafarer_documents with document_files), sets has_attachments = true and populates supporting_documents (SeafarerDocumentFileIds from seafarer_document_files, AuthenticationDocumentFileIds = []). Uses dblink synergy_seafarer. Must run AFTER seafarer_joining_documents_migration and document_files migration.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_documents` before insert (full table reload).
- Orchestration dependencies: `seafarer_documents`, `seafarer_document_files`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `seafarer_uuid`, `new_id` | - | - |
| `document_devation_reasons_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `document_progress_status_lookup` | FK lookup | `dps.id`, `dps.code`, `dps.name`, `normalized_code`, `normalized_name` | - | `smac_master_migration` |
| `seafarer_document_files_lookup` | FK lookup | `seafarer_document_uuid`, `file_ids` | - | `synergy_seafarer` |
| `seafarer_authentication_document_files_lookup` | Seafarer ID mapping (from current database - smac_crewi | `seafarer_document_uuid`, `file_ids` | - | `synergy_seafarer` |

### `seafarers_id_mapping`

- **Output columns**: seafarer_uuid, new_id

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    id as seafarer_uuid,
    id as new_id
FROM public.seafarers
WHERE id IS NOT NULL;
```

### `document_devation_reasons_id_mapping`

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

### `seafarer_document_files_lookup`

- **Output columns**: seafarer_document_uuid, file_ids
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_document_files_lookup AS
SELECT
    seafarer_document_uuid,
    array_agg(id ORDER BY id) as file_ids
FROM dblink('synergy_seafarer',
    'SELECT seafarer_document_uuid, id FROM document.document_files WHERE seafarer_document_uuid IS NOT NULL AND id IS NOT NULL'
) AS df(seafarer_document_uuid uuid, id uuid)
GROUP BY seafarer_document_uuid;
```

### `seafarer_authentication_document_files_lookup`

- **Purpose**: Seafarer ID mapping (from current database - smac_crewi
- **Output columns**: seafarer_document_uuid, file_ids
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_authentication_document_files_lookup AS
SELECT
    seafarer_document_uuid,
    array_agg(id ORDER BY id) as file_ids
FROM dblink('synergy_seafarer',
    'SELECT seafarer_document_uuid, id FROM document.authentication_document_files WHERE seafarer_document_uuid IS NOT NULL AND id IS NOT NULL'
) AS adf(seafarer_document_uuid uuid, id uuid)
GROUP BY seafarer_document_uuid;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'document'::VARCHAR(100), 'seafarer_documents'::VARCHAR(100), sd.id::text, current_database()::text::VARCHAR(100),... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | document_id | - | sd.document_uuid AS document_id | sd.document_uuid |
| 4 | derived | - | document_parts_id | - | sd.document_part_uuid AS document_parts_id | sd.document_part_uuid |
| 5 | derived | - | reference_number | - | NULLIF(TRIM(sd.document_number), '') AS reference_number | NULLIF(TRIM(sd.document_number), '') |
| 6 | derived | - | issue_date | - | CASE WHEN sd.issue_date IS NOT NULL THEN sd.issue_date::date ELSE NULL END AS issue_date | CASE WHEN sd.issue_date IS NOT NULL THEN sd.issue_date::date ELSE NULL END |
| 7 | derived | - | expiry_date | - | CASE WHEN sd.expiry_date IS NOT NULL THEN sd.expiry_date::date ELSE NULL END AS expiry_date | CASE WHEN sd.expiry_date IS NOT NULL THEN sd.expiry_date::date ELSE NULL END |
| 8 | derived | - | issuing_authority | - | NULLIF(TRIM(sd.issuing_authority), '') AS issuing_authority | NULLIF(TRIM(sd.issuing_authority), '') |
| 9 | derived | - | place_of_issue | - | NULLIF(TRIM(sd.place_of_issue), '') AS place_of_issue | NULLIF(TRIM(sd.place_of_issue), '') |
| 10 | derived | - | remarks | - | NULLIF(TRIM(sd.remark), '') AS remarks | NULLIF(TRIM(sd.remark), '') |
| 11 | derived | - | has_document | - | COALESCE(sd.is_seafarer_attachment_present, false) AS has_document | COALESCE(sd.is_seafarer_attachment_present, false) |
| 12 | - | - | no_document_reason | - | NULL | NULL::text |
| 13 | derived | - | version | - | COALESCE(sd.version, 1) AS version | COALESCE(sd.version, 1) |
| 14 | derived | - | bypass_status | - | sd.bypass_status AS bypass_status | sd.bypass_status |
| 15 | derived | - | bypass_reason_id | - | ddr_mapping.new_id AS bypass_reason_id | ddr_mapping.new_id |
| 16 | derived | - | bypass_by_id | - | CASE WHEN sd.bypass_by IS NOT NULL AND sd.bypass_by::text != '{}' AND sd.bypass_by ? 'VerifiedById' AND (sd.bypass_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[... | CASE WHEN sd.bypass_by IS NOT NULL AND sd.bypass_by::text != '{}' AND sd.bypass_by ? 'VerifiedById' AND (sd.bypass_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[... |
| 17 | derived | - | bypass_reason | - | NULLIF(TRIM(sd.deviate_note), '') AS bypass_reason | NULLIF(TRIM(sd.deviate_note), '') |
| 18 | derived | - | has_attachments | - | COALESCE(array_length(df_lookup.file_ids, 1) > 0, false) AS has_attachments | COALESCE(array_length(df_lookup.file_ids, 1) > 0, false) |
| 19 | derived | - | form_response | - | CASE WHEN sd.form_response IS NULL OR sd.form_response::text = 'null' OR sd.form_response::text = '{}' THEN NULL WHEN jsonb_typeof(sd.form_response) = 'array' THEN ( SELECT json... | CASE WHEN sd.form_response IS NULL OR sd.form_response::text = 'null' OR sd.form_response::text = '{}' THEN NULL WHEN jsonb_typeof(sd.form_response) = 'array' THEN ( SELECT json... |
| 20 | derived | - | supporting_documents | - | jsonb_build_object( 'SeafarerDocumentFileIds', COALESCE( (SELECT jsonb_agg(file_id ORDER BY file_id) FROM unnest(COALESCE(df_lookup.file_ids, ARRAY[]::uuid[])) AS file_id WHERE ... | jsonb_build_object( 'SeafarerDocumentFileIds', COALESCE( (SELECT jsonb_agg(file_id ORDER BY file_id) FROM unnest(COALESCE(df_lookup.file_ids, ARRAY[]::uuid[])) AS file_id WHERE ... |
| 21 | - | - | metadata | - | NULL | NULL::jsonb |
| 22 | derived | - | workflow_status_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS workflow_status_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 23 | - | - | progress_status_id | - | COALESCE( (SELECT id FROM document_progress_status_lookup WHERE normalized_code = UPPER(TRIM(COALESCE(sd.status, ''))) LIMIT 1), (SELECT id FROM document_progress_status_lookup ... | COALESCE( (SELECT id FROM document_progress_status_lookup WHERE normalized_code = UPPER(TRIM(COALESCE(sd.status, ''))) LIMIT 1), (SELECT id FROM document_progress_status_lookup ... |
| 24 | derived | - | verified_at | - | CASE WHEN sd.verified_by IS NOT NULL AND sd.verified_by::text != '{}' AND sd.verified_by ? 'VerifiedAt' THEN (sd.verified_by->>'VerifiedAt')::timestamp ELSE NULL END AS verified_at | CASE WHEN sd.verified_by IS NOT NULL AND sd.verified_by::text != '{}' AND sd.verified_by ? 'VerifiedAt' THEN (sd.verified_by->>'VerifiedAt')::timestamp ELSE NULL END |
| 25 | derived | - | verified_by_id | - | CASE WHEN sd.verified_by IS NOT NULL AND sd.verified_by::text != '{}' AND sd.verified_by ? 'VerifiedById' AND (sd.verified_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a... | CASE WHEN sd.verified_by IS NOT NULL AND sd.verified_by::text != '{}' AND sd.verified_by ? 'VerifiedById' AND (sd.verified_by->>'VerifiedById') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a... |
| 26 | - | - | verification_notes | - | NULL | NULL::text |
| 27 | derived | - | approved_by_id | - | CASE WHEN sd.audit_info IS NOT NULL THEN CASE WHEN sd.audit_info ? 'approved_by' AND (sd.audit_info->>'approved_by') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]... | CASE WHEN sd.audit_info IS NOT NULL THEN CASE WHEN sd.audit_info ? 'approved_by' AND (sd.audit_info->>'approved_by') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]... |
| 28 | - | - | approved_at | - | NULL | NULL::timestamp |
| 29 | derived | - | approval_notes | - | NULLIF(TRIM(sd.approval_comment), '') AS approval_notes | NULLIF(TRIM(sd.approval_comment), '') |
| 30 | derived | - | status | - | CASE WHEN sd.is_archived = true THEN 'Archived'::text WHEN sd.is_active = true THEN 'Active'::text WHEN sd.is_active = false THEN 'Inactive'::text ELSE 'Draft'::text END AS status | CASE WHEN sd.is_archived = true THEN 'Archived'::text WHEN sd.is_active = true THEN 'Active'::text WHEN sd.is_active = false THEN 'Inactive'::text ELSE 'Draft'::text END |
| 31 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 32 | derived | - | created_at | - | COALESCE( CASE WHEN sd.audit_info IS NOT NULL AND sd.audit_info ? 'created_at' THEN (sd.audit_info->>'created_at')::timestamp ELSE NULL END, NOW() ) AS created_at | COALESCE( CASE WHEN sd.audit_info IS NOT NULL AND sd.audit_info ? 'created_at' THEN (sd.audit_info->>'created_at')::timestamp ELSE NULL END, NOW() ) |
| 33 | derived | - | updated_at | - | COALESCE(sd.updated_at, NOW()) AS updated_at | COALESCE(sd.updated_at, NOW()) |
| 34 | derived | - | archived_at | - | CASE WHEN sd.is_archived = true THEN COALESCE(sd.updated_at, NOW()) ELSE NULL END AS archived_at | CASE WHEN sd.is_archived = true THEN COALESCE(sd.updated_at, NOW()) ELSE NULL END |
| 35 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 36 | derived | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN sd.audit_info IS NOT NULL AND sd.audit_info ? 'CreatedById' AND sd.audit_info->>'CreatedById' IS NOT NULL AND sd.audit_info->>'Create... | jsonb_build_object( 'created_by', CASE WHEN sd.audit_info IS NOT NULL AND sd.audit_info ? 'CreatedById' AND sd.audit_info->>'CreatedById' IS NOT NULL AND sd.audit_info->>'Create... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `seafarer_uuid, new_id`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    id as seafarer_uuid,
    id as new_id
FROM public.seafarers
WHERE id IS NOT NULL;
```

### 2. Document Devation Reasons ID Mapping
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

### 4. Seafarer Document Files ID Mapping
**Output columns**: `seafarer_document_uuid, file_ids`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_document_files_lookup AS
SELECT
    seafarer_document_uuid,
    array_agg(id ORDER BY id) as file_ids
FROM dblink('synergy_seafarer',
    'SELECT seafarer_document_uuid, id FROM document.document_files WHERE seafarer_document_uuid IS NOT NULL AND id IS NOT NULL'
) AS df(seafarer_document_uuid uuid, id uuid)
GROUP BY seafarer_document_uuid;
```

### 5. Seafarer Authentication Document Files ID Mapping
**Purpose**: Seafarer ID mapping (from current database - smac_crewi
**Output columns**: `seafarer_document_uuid, file_ids`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_authentication_document_files_lookup AS
SELECT
    seafarer_document_uuid,
    array_agg(id ORDER BY id) as file_ids
FROM dblink('synergy_seafarer',
    'SELECT seafarer_document_uuid, id FROM document.authentication_document_files WHERE seafarer_document_uuid IS NOT NULL AND id IS NOT NULL'
) AS adf(seafarer_document_uuid uuid, id uuid)
GROUP BY seafarer_document_uuid;
```

Full migration context: `04-migration-scripts/crewing/seafarer_documents_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_documents_validation.sql` if available
- Run `06-rollback/crewing/seafarer_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
