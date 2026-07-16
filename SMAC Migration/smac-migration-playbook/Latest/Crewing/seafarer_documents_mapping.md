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

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Documents (`seafarer_documents` → `seafarer_documents`)

## Migration Notes

- Source: `document.seafarer_documents` (SAC document schema)
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_uuid` → `seafarer_id` via direct `seafarers` lookup; `document_uuid`/`document_part_uuid` copied to `document_id`/`document_parts_id`
- Column renames: `document_number` → `reference_number`, `remark` → `remarks`, `approval_comment` → `approval_notes`
- `form_response` normalized (fieldId/fieldValue → FieldId/FieldValue); `supporting_documents` built from file lookups
- `status` (text) → `progress_status_id` via `document_progress_status` lookup; record `status` from `is_active`/`is_archived`
- `verified_by`/`bypass_by` JSONB fields parsed for UUID/timestamp extraction
- Requires `seafarers`, `document_devation_reasons`, `document_progress_status` master data

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves legacy UUID |
| 2 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; nil UUID fallback | FK to `seafarers.id` |
| 3 | `document_uuid` | uuid | `document_id` | uuid | Direct copy | FK to master document |
| 4 | `document_part_uuid` | uuid | `document_parts_id` | uuid | Direct copy | Nullable FK |
| 5 | `document_number` | varchar | `reference_number` | text | `NULLIF(TRIM(document_number), '')` | Column rename |
| 6 | `issue_date` | timestamp | `issue_date` | date | `issue_date::date` | Timestamp → date |
| 7 | `expiry_date` | timestamp | `expiry_date` | date | `expiry_date::date` | Timestamp → date |
| 8 | `issuing_authority` | varchar | `issuing_authority` | text | `NULLIF(TRIM(issuing_authority), '')` | Direct copy |
| 9 | `place_of_issue` | varchar | `place_of_issue` | text | `NULLIF(TRIM(place_of_issue), '')` | Direct copy |
| 10 | `remark` | varchar | `remarks` | text | `NULLIF(TRIM(remark), '')` | Column rename |
| 11 | `is_seafarer_attachment_present` | boolean | `has_document` | boolean | `COALESCE(is_seafarer_attachment_present, false)` | Column rename |
| 12 | — | — | `no_document_reason` | text | `NULL` | No SAC equivalent |
| 13 | `version` | integer | `version` | integer | `COALESCE(version, 1)` | NOT NULL default 1 |
| 14 | `bypass_status` | text | `bypass_status` | text | Direct copy | |
| 15 | `deviate_reason_id` | bigint | `bypass_reason_id` | uuid | Map via `document_devation_reasons_id_mapping` | Lookup: master mappings |
| 16 | `bypass_by` (JSONB) | jsonb | `bypass_by_id` | uuid | Extract `VerifiedById` when valid UUID | Parsed from JSONB |
| 17 | `deviate_note` | text | `bypass_reason` | text | `NULLIF(TRIM(deviate_note), '')` | Column rename |
| 18 | `document_files` (derived) | — | `has_attachments` | boolean | `true` when file_ids array non-empty | From file lookup temp tables |
| 19 | `form_response` | jsonb | `form_response` | jsonb | Normalize at INSERT; country `FieldValue` UUID backfill post-migration | See Post-Migration Updates |
| 20 | `document_files` (derived) | — | `supporting_documents` | jsonb | `{SeafarerDocumentFileIds, AuthenticationDocumentFileIds}` from file lookups | Built JSON object |
| 21 | — | — | `metadata` | jsonb | `NULL` | No SAC equivalent |
| 22 | — | — | `workflow_status_id` | uuid | Hardcoded nil UUID | NOT NULL placeholder |
| 23 | `status` | text | `progress_status_id` | uuid | Match `document_progress_status` by code or name (case-insensitive) | Lookup: `document.document_progress_status` |
| 24 | `verified_by` (JSONB) | jsonb | `verified_at` | timestamp | Extract `VerifiedAt` | Parsed from JSONB |
| 25 | `verified_by` (JSONB) | jsonb | `verified_by_id` | uuid | Extract `VerifiedById` when valid UUID | Parsed from JSONB |
| 26 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 27 | `audit_info` (JSONB) | jsonb | `approved_by_id` | uuid | Extract `approved_by` / `approved_by_id` / `user_id` when valid UUID | Parsed from SAC audit_info |
| 28 | — | — | `approved_at` | timestamp | `NULL` | No SAC equivalent |
| 29 | `approval_comment` | text | `approval_notes` | text | `NULLIF(TRIM(approval_comment), '')` | Column rename |
| 30 | `is_active`, `is_archived` | boolean | `status` | text | Archived / Active / Inactive / Draft based on flags | Record lifecycle status |
| 31 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 32 | `audit_info` → `created_at` | jsonb | `created_at` | timestamp | Extract from audit_info or `NOW()` | Fallback chain |
| 33 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 34 | `is_archived`, `updated_at` | boolean, timestamp | `archived_at` | timestamp | `updated_at` when `is_archived = true` | Archive timestamp |
| 35 |  `audit_info` → `deleted_at` | jsonb | `deleted_at` | timestamp | `NULL` | SAC audit_info.deleted_at mapped to SMAC deleted_at column |
| 36 | `audit_info` | jsonb | `audit_info` | jsonb | Standard SMAC structure merged from SAC audit_info fields | Handles CreatedById/UpdatedById variants |

**SMAC columns not migrated:** `no_document_reason`, `metadata`, `workflow_status_id` (nil UUID placeholder), `verification_notes`, `approved_at`, `deleted_at` — no SAC source equivalents.

**SAC columns not migrated:** Columns in source not in dblink SELECT — verify discovery script for any additional legacy fields not referenced in migration.

### Post-Migration Updates

#### `update_seafarer_documents_country_fieldvalue.sql`

| Target Table | Target Column | Legacy Source Table | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|---------------------|---------------|-------------|----------------|------------|
| `public.seafarer_documents` | `form_response[].FieldValue` (country fields) | `synergy_master.document.document_field_definition` | `name = 'country'` | text | Numeric `FieldValue` (legacy country bigint) → UUID via `smac_master_migration.migration.table_mappings` (`countries`) | `FieldValue` matches `^[0-9]+$`; field `FieldId` resolved from master |

**Lookup tables:** `synergy_master.document.document_field_definition` (dblink); `smac_master_migration.migration.table_mappings` (`countries`).

**Notes:** Migration may leave country `FieldValue` as legacy integer ID in JSON array; this update converts to SMAC country UUID.

#### `update_seafarer_documents_has_attachments.sql` (SMAC-only)

Propagates `supporting_documents` from part rows to parent rows and sets `has_attachments` from SMAC `seafarer_document_files` — no additional SAC mapping.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_document_files`
- `seafarer_documents`

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