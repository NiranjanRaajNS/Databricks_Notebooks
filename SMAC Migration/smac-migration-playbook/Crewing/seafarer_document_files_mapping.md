# Table Mapping: seafarer_document_files → seafarer_document_files

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_document_files
- **Source Script**: `04-migration-scripts/crewing/seafarer_document_files_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.document_files + document.authentication_document_files`
- **New Path**: `smac_crewing_migration.public.seafarer_document_files`

## Migration Notes

- Data from both source tables are combined using UNION ALL
- Post-migration update: Normalizes status to enum text (Active=0, Draft=1, Inactive=2, Deleted=3, Archived=4). Converts integer columns to text when needed. Must run AFTER seafarer_document_files migration.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_document_files` before insert (full table reload).
- Orchestration dependencies: `seafarer_document_files`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'document'::VARCHAR(100), 'document_files'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | seafarer_id | - | sd.seafarer_id AS seafarer_id | sd.seafarer_id |
| 3 | seafarer_document_uuid | - | seafarer_document_id | - | legacy_data.seafarer_document_uuid AS seafarer_document_id | legacy_data.seafarer_document_uuid |
| 4 | file_name | - | file_name | - | NULLIF(TRIM(legacy_data.file_name), '') AS file_name | NULLIF(TRIM(legacy_data.file_name), '') |
| 5 | file_content_type | - | file_content_type | - | NULLIF(TRIM(legacy_data.file_content_type), '') AS file_content_type | NULLIF(TRIM(legacy_data.file_content_type), '') |
| 6 | file_size | - | file_size | - | COALESCE(legacy_data.file_size, 0) AS file_size | COALESCE(legacy_data.file_size, 0) |
| 7 | url | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') AS file_url | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') |
| 8 | - | - | checksum | - | NULL | NULL::text |
| 9 | derived | - | version_number | - | 1 AS version_number | 1 |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 16 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_document_files_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_document_files_validation.sql` if available
- Run `06-rollback/crewing/seafarer_document_files_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
