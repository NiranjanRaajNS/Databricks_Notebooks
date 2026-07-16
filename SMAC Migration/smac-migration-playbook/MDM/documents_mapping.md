# Table Mapping: documents → documents

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: documents
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: documents
- **Source Script**: `04-migration-scripts/master/documents_migration.sql`

- **Legacy Path**: `synergy_master.document.documents`
- **New Path**: `smac_master_migration.document.documents`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Documents (`documents` → `documents`)

## Migration Notes

- Preserve legacy id (uuid) as new id (uuid)
- Map all columns including arrays and foreign keys
- Map status from text to integer
- Map section (text) to document_section_id (uuid) via migration.table_mappings
- Migrates documents preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE document.documents` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `document_type_id_mapping` | Check for duplicate UUIDs in source table | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `document_subtype_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `document_section_id_mapping` | Check if | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `document_tag_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `document_type_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=document_types

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

### `document_subtype_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=document_subtypes

```sql
CREATE TEMP TABLE document_subtype_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_subtypes'
  AND target_db = current_database();
```

### `document_section_id_mapping`

- **Purpose**: Check if
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=document_sections

```sql
CREATE TEMP TABLE document_section_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_sections'
  AND target_db = current_database();
```

### `document_tag_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=document_tags

```sql
CREATE TEMP TABLE document_tag_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_tags'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'documents'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), '... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 4 | derived | - | document_type_id | - | dtm.target_id as document_type_id | dtm.target_id |
| 5 | derived | - | document_subtype_id | - | dsm.target_id as document_subtype_id | dsm.target_id |
| 6 | derived | - | document_section_id | - | dsec_map.target_id as document_section_id | dsec_map.target_id |
| 7 | cushion_period | - | cushion_period | - | legacy_data.cushion_period | legacy_data.cushion_period |
| 8 | document_tag_ids | - | document_tag_ids | - | CASE WHEN legacy_data.document_tag_ids IS NULL OR array_length(legacy_data.document_tag_ids, 1) IS NULL THEN NULL ELSE ( SELECT array_agg(tag_map.target_id ORDER BY tag_idx) FRO... | CASE WHEN legacy_data.document_tag_ids IS NULL OR array_length(legacy_data.document_tag_ids, 1) IS NULL THEN NULL ELSE ( SELECT array_agg(tag_map.target_id ORDER BY tag_idx) FRO... |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 11 | derived | - | version | - | 1 as version | 1 |
| 12 | audit_info | - | created_at | - | COALESCE( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL THEN (legacy_data.audit_info->>'CreatedAt')::timestamp ELSE NULL END,... | COALESCE( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL THEN (legacy_data.audit_info->>'CreatedAt')::timestamp ELSE NULL END,... |
| 13 | audit_info, updated_at | - | updated_at | - | COALESCE( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL THEN (legacy_data.audit_info->>'UpdatedAt')::timestamp ELSE NULL END,... | COALESCE( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL THEN (legacy_data.audit_info->>'UpdatedAt')::timestamp ELSE NULL END,... |
| 14 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 15 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | identifier | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.identifier), ''), '') as code | COALESCE(NULLIF(TRIM(legacy_data.identifier), ''), '') |
| 18 | derived | - | sync_to_vessel | - | false as sync_to_vessel | false |
| 19 | identifier | - | identifier | - | legacy_data.identifier as identifier | legacy_data.identifier |
| 20 | authentication_required | - | authentication_required | - | legacy_data.authentication_required as authentication_required | legacy_data.authentication_required |
| 21 | is_active | - | is_active | - | legacy_data.is_active as is_active | legacy_data.is_active |
| 22 | is_allow_multiple_attachments | - | is_allow_multiple_attachments | - | legacy_data.is_allow_multiple_attachments as is_allow_multiple_attachments | legacy_data.is_allow_multiple_attachments |
| 23 | is_allow_versioning | - | is_allow_versioning | - | legacy_data.is_allow_versioning as is_allow_versioning | legacy_data.is_allow_versioning |
| 24 | is_child_document | - | is_child_document | - | legacy_data.is_child_document as is_child_document | legacy_data.is_child_document |
| 25 | is_internal_document | - | is_internal_document | - | legacy_data.is_internal_document as is_internal_document | legacy_data.is_internal_document |
| 26 | is_main_document | - | is_main_document | - | legacy_data.is_main_document as is_main_document | legacy_data.is_main_document |
| 27 | is_multipart_document | - | is_multipart_document | - | legacy_data.is_multipart_document as is_multipart_document | legacy_data.is_multipart_document |
| 28 | is_optional_if_parent_exists | - | is_optional_if_parent_exists | - | legacy_data.is_optional_if_parent_exists as is_optional_if_parent_exists | legacy_data.is_optional_if_parent_exists |
| 29 | is_part_document | - | is_part_document | - | legacy_data.is_part_document as is_part_document | legacy_data.is_part_document |
| 30 | is_verification_required | - | is_verification_required | - | legacy_data.is_verification_required as is_verification_required | legacy_data.is_verification_required |
| 31 | is_versioning_requires_new_doc | - | is_versioning_requires_new_doc | - | legacy_data.is_versioning_requires_new_doc as is_versioning_requires_new_doc | legacy_data.is_versioning_requires_new_doc |
| 32 | minimal_validity_period | - | minimal_validity_period | - | legacy_data.minimal_validity_period as minimal_validity_period | legacy_data.minimal_validity_period |
| 33 | derived | - | "number" | - | legacy_data."number" as "number" | legacy_data."number" as "number" |
| 34 | part_completion_rules | - | part_completion_rules | - | legacy_data.part_completion_rules as part_completion_rules | legacy_data.part_completion_rules |
| 35 | permission | - | permission | - | COALESCE(legacy_data.permission, '{}'::jsonb) as permission | COALESCE(legacy_data.permission, '{}'::jsonb) |
| 36 | priority | - | priority | - | COALESCE(legacy_data.priority, 0) as priority | COALESCE(legacy_data.priority, 0) |
| 37 | superior_document_ids | - | superior_document_ids | - | legacy_data.superior_document_ids as superior_document_ids | legacy_data.superior_document_ids |
| 38 | temp_id | - | temp_id | - | legacy_data.temp_id as temp_id | legacy_data.temp_id |
| 39 | derived | - | vessel_id | - | NULL as vessel_id | NULL |
| 40 | derived | - | document_applicability_scope_id | - | NULL as document_applicability_scope_id | NULL |
| 41 | parent_document_id | - | parent_document_id | - | legacy_data.parent_document_id as parent_document_id | legacy_data.parent_document_id |
| 42 | derived | - | ref_number | - | NULL as ref_number | NULL |
| 43 | derived | - | level | - | 0 as level | 0 |
| 44 | identifier, name | - | tags | - | CASE WHEN LOWER(COALESCE(TRIM(legacy_data.identifier), '')) != LOWER( REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '... | CASE WHEN LOWER(COALESCE(TRIM(legacy_data.identifier), '')) != LOWER( REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '... |
| 45 | name, identifier | - | document_mode | - | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(COALESCE(... | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(legacy_data.name, 'UNKNOWN'), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[LOWER(COALESCE(... |
| 46 | derived | - | form_definition_id | - | 0 as document_mode | 0 as document_mode |
| 47 | derived | - | status | - | NULL as form_definition_id | NULL as form_definition_id |
| 48 | status | - | workflow_status | - | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... |
| 49 | - | - | defined_by | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer as workflow_status |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Document Type ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='document_types'`

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

### 2. Document Subtype ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='document_subtypes'`

```sql
CREATE TEMP TABLE document_subtype_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_subtypes'
  AND target_db = current_database();
```

### 3. Document Section ID Mapping
**Purpose**: Check if
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='document_sections'`

```sql
CREATE TEMP TABLE document_section_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_sections'
  AND target_db = current_database();
```

### 4. Document Tag ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='document_tags'`

```sql
CREATE TEMP TABLE document_tag_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_tags'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/documents_migration.sql`

## Validation

- Run `05-validation/master/documents_validation.sql` if available
- Run `06-rollback/master/documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
