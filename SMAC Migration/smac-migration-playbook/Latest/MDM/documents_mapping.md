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

- Source: `synergy_master.document.documents`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- FK lookups: `document_type_id`, `document_subtype_id`, `document_section_id`, `document_tag_ids` via temp mapping tables
- `status` mapped from text; timestamps from `audit_info` JSONB with fallbacks
- Second INSERT: manual seed rows (e.g. Letter Of Indemnity M16) not from SAC
- Requires document_types, document_subtypes, document_sections, document_tags migrated first


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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `name` | character varying(250) | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `description` | character varying(250) | `description` | text | `TRIM(description)` | |
| 4 | `document_type_id` | uuid | `document_type_id` | uuid | Map via `document_type_id_mapping` | FK: `document_types` |
| 5 | `document_subtype_id` | uuid | `document_subtype_id` | uuid | Map via `document_subtype_id_mapping` | FK: `document_subtypes` |
| 6 | `document_section_id` | uuid | `document_section_id` | uuid | Map via `document_section_id_mapping` | FK: `document_sections` |
| 7 | `cushion_period` | integer | `cushion_period` | integer | Direct copy | |
| 8 | `document_tag_ids` | uuid[] | `document_tag_ids` | uuid[] | Map each element via `document_tag_id_mapping`; NULL when empty | FK array: `document_tags` |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 10 | — | — | `parent_id` | uuid | `NULL` | Not in SAC |
| 11 | — | — | `version` | integer | Hardcoded `1` | |
| 12 | `audit_info`, `updated_at` | jsonb, timestamp | `created_at` | timestamp without time zone | Extract `CreatedAt` from audit_info; fallback `NOW()` | |
| 13 | `audit_info`, `updated_at` | jsonb, timestamp | `updated_at` | timestamp without time zone | Extract `UpdatedAt`; fallback `updated_at`; then `NOW()` | |
| 14 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC |
| 16 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | SAC audit_info not mapped directly |
| 17 | `identifier` | character varying(250) | `code` | text | `COALESCE(NULLIF(TRIM(identifier), ''), '')` | |
| 18 | — | — | `sync_to_vessel` | boolean | Hardcoded `false` | Not in SAC |
| 19 | `identifier` | character varying(250) | `identifier` | text | Direct copy | |
| 20 | `authentication_required` | boolean | `authentication_required` | boolean | Direct copy | |
| 21 | `is_active` | boolean | `is_active` | boolean | Direct copy | |
| 22 | `is_allow_multiple_attachments` | boolean | `is_allow_multiple_attachments` | boolean | Direct copy | |
| 23 | `is_allow_versioning` | boolean | `is_allow_versioning` | boolean | Direct copy | |
| 24 | `is_child_document` | boolean | `is_child_document` | boolean | Direct copy | |
| 25 | `is_internal_document` | boolean | `is_internal_document` | boolean | Direct copy | |
| 26 | `is_main_document` | boolean | `is_main_document` | boolean | Direct copy | |
| 27 | `is_multipart_document` | boolean | `is_multipart_document` | boolean | Direct copy | |
| 28 | `is_optional_if_parent_exists` | boolean | `is_optional_if_parent_exists` | boolean | Direct copy | |
| 29 | `is_part_document` | boolean | `is_part_document` | boolean | Direct copy | |
| 30 | `is_verification_required` | boolean | `is_verification_required` | boolean | Direct copy | |
| 31 | `is_versioning_requires_new_doc` | boolean | `is_versioning_requires_new_doc` | boolean | Direct copy | |
| 32 | `minimal_validity_period` | integer | `minimal_validity_period` | integer | Direct copy | |
| 33 | `number` | character varying(250) | `number` | text | Direct copy | |
| 34 | `part_completion_rules` | jsonb | `part_completion_rules` | jsonb | Direct copy | |
| 35 | `permission` | jsonb | `permission` | jsonb | `COALESCE(permission, '{}'::jsonb)` | |
| 36 | `priority` | integer | `priority` | integer | `COALESCE(priority, 0)` | |
| 37 | `superior_document_ids` | uuid[] | `superior_document_ids` | uuid[] | Direct copy | UUIDs preserved |
| 38 | `temp_id` | integer | `temp_id` | integer | Direct copy | |
| 39 | — | — | `vessel_id` | uuid | `NULL` | Not in SAC |
| 40 | — | — | `document_applicability_scope_id` | uuid | `NULL` | Not in SAC |
| 41 | `parent_document_id` | uuid | `parent_document_id` | uuid | Direct copy | Same UUID preserved |
| 42 | — | — | `ref_number` | text | `NULL` | Not in SAC |
| 43 | — | — | `level` | numeric | Hardcoded `0` | |
| 44 | `identifier`, `name` | character varying, character varying | `tags` | text[] | Distinct lowercase tags from identifier + normalized name | Derived |
| 45 | — | — | `document_mode` | integer | Hardcoded `0` | Not in SAC |
| 46 | — | — | `form_definition_id` | uuid | `NULL` | Not in SAC |
| 47 | `status` | text | `status` | integer | Map ACTIVE/DRAFT/INACTIVE/DELETED text or numeric to integer | |
| 48 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 49 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |

**Additional seed records (not from SAC):** Manual INSERT rows (e.g. Letter Of Indemnity M16) via second INSERT block.


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

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
