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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID per SAC file row |
| 2 | `mapper_uuid` | uuid | `entity_document_id` | uuid | Join `entity_document_id_mapping` on `mapper_uuid` | Lookup: `entity_documents` mappings; NOT NULL |
| 3 | `file_name` | text | `file_name` | text | `TRIM(file_name)` | NOT NULL |
| 4 | `content_type` | text | `file_content_type` | text | `TRIM(content_type)` | Nullable |
| 5 | `content_size` | bigint | `file_size` | bigint | Direct copy | NOT NULL |
| 6 | `url` | text | `file_url` | text | `TRIM(url)` | NOT NULL |
| 7 | — | — | `checksum` | text | `NULL` | No equivalent in SAC |
| 8 | — | — | `version_number` | integer | Hardcoded `1` | SMAC default |
| 9 | — | — | `status` | integer | Hardcoded `0` (Active per `constants.sql`) | NOT NULL |
| 10 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | NOT NULL |
| 13 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 15 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | Standardized SMAC audit |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `document_name`, `sign_off_detail_id` — parent-level fields on `entity_documents`; `mapper_uuid` used only for parent FK join.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `entity_documents`

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
