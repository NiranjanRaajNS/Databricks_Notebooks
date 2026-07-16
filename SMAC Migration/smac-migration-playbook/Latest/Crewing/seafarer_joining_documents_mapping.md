# Table Mapping: seafarer_joining_documents → seafarer_documents

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_documents (joining documents) — staged via `joining_document_summary` built from `seafarer_joining_documents` + `seafarer_documents`
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_documents (Part 1); script also migrates `seafarer_document_files` and `seafarer_assignment_documents`
- **Source Script**: `04-migration-scripts/crewing/seafarer_joining_documents_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_documents` (joining documents) + `synergy_seafarer.public.seafarer_joining_documents`
- **New Path**: `smac_crewing_migration.public.seafarer_documents`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Joining Documents (`seafarer_documents` → `seafarer_documents`, group: CrewingShoreAssignment)

## Migration Notes

- Multi-part script: (1) `seafarer_documents`, (2) `seafarer_document_files`, (3) `seafarer_assignment_documents` — column mapping covers Part 1 primary INSERT
- Uses pre-built `joining_document_summary` staging table (relief_summary + assignments pre-joined)
- SAC `uuid` preserved as SMAC `id` via `COALESCE(doc_id_map.target_id, jds.uuid)` (Pattern 4)
- `smac_seafarer_id` used directly for `seafarer_id` (already resolved UUID)
- `document_id` from `document_sub_category_uuid`; nil UUID fallback
- `form_response` from pre-transformed `formio_response` in summary table
- `progress_status_id` mapped from SAC integer `status` (0–4) via `document_progress_status_lookup`
- `bypass_reason_id` via `document_devation_reasons_id_mapping`
- `bypass_by_id` extracted from `bypass_by` JSON `VerifiedById` field
- Batch processing (5000 rows) with progress logging; append-only for documents
- Requires `seafarers`, `documents` migrated first

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
| 1 | `uuid` | uuid | `id` | uuid | `COALESCE(doc_id_map.target_id, jds.uuid)` | Preserves SAC uuid (Pattern 4); idempotent via existing mappings |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | `COALESCE(smac_seafarer_id, nil UUID)` | Pre-resolved in summary table |
| 3 | `document_sub_category_uuid` | uuid | `document_id` | uuid | `COALESCE(document_sub_category_uuid, nil UUID)` | Document sub-category reference |
| 4 | — | — | `document_parts_id` | uuid | `NULL` | Joining documents have no parts |
| 5 | `number` | text | `reference_number` | text | `NULLIF(TRIM(number), '')` | Document reference number |
| 6 | `issue_date` | timestamp | `issue_date` | date | Cast to date when not NULL | Nullable |
| 7 | `expiry_date` | timestamp | `expiry_date` | date | Cast to date when not NULL | Nullable |
| 8 | `issuing_authority` | text | `issuing_authority` | text | `NULLIF(TRIM(issuing_authority), '')` | Direct copy |
| 9 | `place_of_issue` | text | `place_of_issue` | text | `NULLIF(TRIM(place_of_issue), '')` | Direct copy |
| 10 | `remark` | text | `remarks` | text | `NULLIF(TRIM(remark), '')` | SAC `remark` → SMAC `remarks` |
| 11 | `attachment_status` | integer | `has_document` | boolean | `attachment_status > 0` → true; else false | Derived boolean |
| 12 | — | — | `no_document_reason` | text | `NULL` | Not populated |
| 13 | — | — | `version` | integer | Hardcoded `1` | Initial version |
| 14 | `bypass_status` | integer | `bypass_status` | text | Cast to text when not NULL | Nullable |
| 15 | bypass reason join | uuid | `bypass_reason_id` | uuid | Map via `document_devation_reasons_id_mapping` | Lookup: `document_devation_reasons` mappings |
| 16 | `bypass_by` | jsonb | `bypass_by_id` | uuid | Extract `VerifiedById` when valid UUID | From bypass JSON object |
| 17 | `deviate_note` | text | `bypass_reason` | text | `NULLIF(TRIM(deviate_note), '')` | Deviation note text |
| 18 | SAC `document_files` presence | — | `has_attachments` | boolean | `false` at INSERT; backfilled post-migration | See Post-Migration Updates |
| 19 | `formio_response` | jsonb | `form_response` | jsonb | Direct copy from summary table | Pre-transformed form data |
| 20 | `public.document_files`| - | `supporting_documents` | jsonb | `NULL` at INSERT; backfilled post-migration | See Post-Migration Updates |
| 21 | — | — | `metadata` | jsonb | `NULL` | Not populated |
| 22 | — | — | `workflow_status_id` | uuid | Hardcoded nil UUID | Not resolved from source |
| 23 | `status` | integer | `progress_status_id` | uuid | Map 0–4 to UNVERIFIED/VERIFIED/REQUESTED/etc. | Via `document_progress_status_lookup` |
| 24 | `verified_date` | timestamp | `verified_at` | timestamp without time zone | Cast when not NULL | Nullable |
| 25 | `verified_by_id` | text | `verified_by_id` | uuid | Cast when valid UUID format | Nullable |
| 26 | `approval_comment` | text | `verification_notes` | text | Direct copy | Nullable |
| 27 | — | — | `approved_by_id` | uuid | `NULL` | Not populated |
| 28 | `verified_date` | timestamp | `approved_at` | timestamp without time zone | Copy `verified_date` | Nullable |
| 29 | `approval_comment` | text | `approval_notes` | text | `NULLIF(TRIM(approval_comment), '')` | Nullable |
| 30 | `status` | integer | `status` | text | 0/1→Active; 2→Inactive; 3→Deleted; etc. | Integer to text mapping |
| 31 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 32 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 33 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 34 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not populated |
| 35 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 36 | audit  | - | `audit_info` | jsonb | `jsonb_build_object()` — includes legacy metadata keys |sac audit mapped to audit_info |

**SMAC columns not migrated:** None in Part 1 beyond defaults.

**SAC columns not migrated (stored in audit_info):** `seafarer_doc_id`, `coe_issue_date`, `coe_expiry_date`, `cra_issue_date`, `cra_expiry_date`, `country_id`, `visa_class`, `blockchain_status`, `mandatory_value`, `is_confirmed`, `document_source_id`, `re_try_count`.

### Post-Migration Updates (`update_seafarer_joining_documents_has_attachments.sql`)

| Target Table | Target Column | Legacy Source Table | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|---------------------|---------------|-------------|----------------|------------|
| `public.seafarer_documents` | `has_attachments` | `public.seafarer_documents` + `public.document_files` | `uuid`, `seafarer_document_uuid` / `seafarer_document_id` | uuid, bigint | SAC identifies joining doc UUIDs with files → SMAC match `seafarer_documents.id = uuid` → `has_attachments = true` | Public schema joining docs only |
| `public.seafarer_documents` | `supporting_documents` | SMAC `public.seafarer_document_files` | `id` | uuid | `{"SeafarerDocumentFileIds": [...], "AuthenticationDocumentFileIds": []}` from migrated files | `deleted_at IS NULL`; status ≠ `'3'` |

**SAC dblink:** `synergy_seafarer` — `EXISTS` check on `document_files` linked by `seafarer_document_uuid` (fallback `seafarer_document_id`).

**Notes:** Part 1 migration sets `has_attachments = false` and `supporting_documents = NULL`; this update runs after `seafarer_document_files` migration.

**Additional script parts (not in table above):** Part 2 → `seafarer_document_files`; Part 3 → `seafarer_assignment_documents`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `documents`
- `seafarers`

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
