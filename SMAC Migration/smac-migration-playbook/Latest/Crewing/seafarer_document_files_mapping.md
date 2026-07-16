# Table Mapping: seafarer_document_files → seafarer_document_files

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: document
- **Legacy Table**: document_files, authentication_document_files (UNION ALL)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_document_files
- **Source Script**: `04-migration-scripts/crewing/seafarer_document_files_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.document_files` + `synergy_seafarer.document.authentication_document_files`
- **New Path**: `smac_crewing_migration.public.seafarer_document_files`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Document Files (`document_files` / `authentication_document_files` → `seafarer_document_files`)

## Migration Notes

- Source: `document.document_files` and `document.authentication_document_files` (UNION ALL)
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_document_uuid` copied directly to `seafarer_document_id`; `seafarer_id` from joined `seafarer_documents`
- `url` → `file_url`; `deleted_at` drives integer `status` (0=Active, 3=Deleted)
- Run `seafarer_document_files_status_update_migration.sql` after insert to normalize status to text enum names
- Requires `seafarer_documents` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_document_files` before insert (full table reload).
- Orchestration dependencies: `seafarer_document_files`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves legacy UUID |
| 2 | `seafarer_documents.seafarer_id` (derived) | uuid | `seafarer_id` | uuid | From join to `seafarer_documents` | FK denormalized on file row |
| 3 | `seafarer_document_uuid` | uuid | `seafarer_document_id` | uuid | Direct copy | FK to parent document |
| 4 | `file_name` | varchar | `file_name` | text | `NULLIF(TRIM(file_name), '')` | Direct copy |
| 5 | `file_content_type` | varchar | `file_content_type` | text | `NULLIF(TRIM(file_content_type), '')` | Direct copy |
| 6 | `file_size` | integer | `file_size` | bigint | `COALESCE(file_size, 0)` | NOT NULL; int → bigint |
| 7 | `url` | varchar | `file_url` | text | `COALESCE(NULLIF(TRIM(url), ''), '')` | Column rename |
| 8 | — | — | `checksum` | text | `NULL` | No SAC equivalent |
| 9 | — | — | `version_number` | integer | Hardcoded `1` | Default |
| 10 | `deleted_at` | timestamp | `status` | integer | `3` (Deleted) when `deleted_at IS NOT NULL`, else `0` (Active) | Normalized to text by status_update script |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 12 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 13 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 14 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 15 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 16 | `created_by_id`, `updated_by_id` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` | Standardized SMAC audit structure |

**SMAC columns not migrated:** `checksum`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** None from `document_files` / `authentication_document_files` SELECT lists.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_document_files`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_document_files_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_document_files_validation.sql` if available
- Run `06-rollback/crewing/seafarer_document_files_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
