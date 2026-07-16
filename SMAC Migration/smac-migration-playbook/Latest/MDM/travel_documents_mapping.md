# Table Mapping: travel_document_lists → travel_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: travel_document_lists
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: travel_documents
- **Source Script**: `04-migration-scripts/master/travel_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.travel_document_lists`
- **New Path**: `smac_master_migration.document.travel_documents`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Travel Documents (`travel_document_lists` → `travel_documents`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Pre-migration duplicate UUID check on SAC `uuid` column
- `code` generated from `name` via `generate_meaningful_code()`
- `document_id` via explicit `documents_id_mapping` (identifier → `document.documents.id`)
- `tags` from `travel_document_tag_mapping`; contract fallback; post-migration CSV name match UPDATE
- `status` hardcoded Active (0) — no `deleted_at` in SAC
- Post-migration UPDATE: `tags` from `travel_documents_csv_mapping` by name match
## Special Considerations

- Script performs `TRUNCATE TABLE document.travel_documents` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `documents_id_mapping` | FK lookup | `travel_doc_identifier_upper`, `document_id` | - | - |

### `documents_id_mapping`

- **Output columns**: travel_doc_identifier_upper, document_id

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(tdim.travel_doc_identifier)))
    UPPER(TRIM(tdim.travel_doc_identifier)) as travel_doc_identifier_upper,
    d.id as document_id
FROM travel_document_identifier_mapping tdim

INNER JOIN document.documents d ON UPPER(TRIM(d.identifier)) = UPPER(TRIM(tdim.document_identifier))
WHERE tdim.document_identifier IS NOT NULL
ORDER BY UPPER(TRIM(tdim.travel_doc_identifier)), d.id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid, id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC uuid as SMAC id |
| 2 | `name` | character varying | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name |
| 3 | `name` | character varying | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | `identifier, mandatory_for` | character varying, integer | `is_required` | boolean | `identifier = 'PASSPORT'` → true; else `mandatory_for > 0` | Derived business rule |
| 5 | `—` | — | `is_compliant_check_required` | boolean | Hardcoded `false` | Not in SAC source |
| 6 | `—` | — | `description` | text | `NULL` | Not in SAC source |
| 7 | `identifier` | character varying | `document_id` | uuid | Map via `documents_id_mapping` on normalized identifier | FK to `document.documents` |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 12 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No deleted_at in SAC |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 15 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 16 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 18 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 19 | `identifier` | character varying | `tags` | text[] | `travel_document_tag_mapping`; contract doc fallback `ARRAY['CON','seafarer_contract']` | Post-migration CSV UPDATE by name |
| 20 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |

**SAC columns not migrated:** `is_linked_with_seafarer_document` — not referenced in migration script.

**Post-migration changes (not from SAC column mapping):** UPDATE `tags` from `travel_documents_csv_mapping` where name matches.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Documents ID Mapping
**Output columns**: `travel_doc_identifier_upper, document_id`

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(tdim.travel_doc_identifier)))
    UPPER(TRIM(tdim.travel_doc_identifier)) as travel_doc_identifier_upper,
    d.id as document_id
FROM travel_document_identifier_mapping tdim

INNER JOIN document.documents d ON UPPER(TRIM(d.identifier)) = UPPER(TRIM(tdim.document_identifier))
WHERE tdim.document_identifier IS NOT NULL
ORDER BY UPPER(TRIM(tdim.travel_doc_identifier)), d.id;
```

Full migration context: `04-migration-scripts/master/travel_documents_migration.sql`

## Validation

- Run `05-validation/master/travel_documents_validation.sql` if available
- Run `06-rollback/master/travel_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
