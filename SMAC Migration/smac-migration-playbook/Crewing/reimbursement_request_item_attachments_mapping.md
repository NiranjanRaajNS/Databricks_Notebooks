# Table Mapping: reimbursement_request_item_attachments → seafarer_attachments

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: reimbursement_request_item_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/reimbursement_request_item_attachments_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.reimbursement_request_item_attachments`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Reimbursement Request Item Attachments (`reimbursement_request_item_attachments` → `seafarer_attachments`)

## Migration Notes

- Source table has no status column. Status is derived from deleted_at: 'Deleted' if deleted_at IS NOT NULL, otherwise 'Active'
- Migrates reimbursement_request_item_attachments to seafarer_attachments table. Generates new UUIDs for id column using migration.resolve_target_id() (source id is bigint, target id is uuid). Maps seafarer_id via seafarer_reimbursements table: reimbursement_request_item_id → seafarer_reimbursements.id → seafarer_reimbursements.seafarer_id. Maps reference_id to seafarer_reimbursements.id via migration.table_mappings. Sets reference_entity to 'seafarer_reimbursements'. Sets file_type to 'reimbursement' as default. Maps file_path to file_url. Converts file_size from integer to bigint. Derives status from deleted_at ('Inactive' if deleted_at IS NOT NULL, else 'Active'). Uses standardized SMAC audit_info structure. Requires seafarer_reimbursements to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarer_reimbursements`, `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() AS id | gen_random_uuid() |
| 2 | derived | - | seafarer_id | - | sr.seafarer_id AS seafarer_id | sr.seafarer_id |
| 3 | derived | - | file_type | - | 'Reimbursement' AS file_type | 'Reimbursement' |
| 4 | derived | - | file_sub_type | - | NULL AS file_sub_type | NULL |
| 5 | derived | - | master_document_id | - | NULL AS master_document_id | NULL |
| 6 | file_name | - | file_name | - | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), 'unnamed_file') AS file_name | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), 'unnamed_file') |
| 7 | content_type | - | file_content_type | - | NULLIF(TRIM(legacy_data.content_type), '') AS file_content_type | NULLIF(TRIM(legacy_data.content_type), '') |
| 8 | file_size | - | file_size | - | CAST(COALESCE(legacy_data.file_size, 0) AS bigint) AS file_size | CAST(COALESCE(legacy_data.file_size, 0) AS bigint) |
| 9 | file_path | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.file_path), ''), '') AS file_url | COALESCE(NULLIF(TRIM(legacy_data.file_path), ''), '') |
| 10 | derived | - | checksum | - | NULL AS checksum | NULL |
| 11 | derived | - | reference_entity | - | 'seafarer_reimbursements' AS reference_entity | 'seafarer_reimbursements' |
| 12 | derived | - | reference_id | - | reimbursement_map.target_id AS reference_id | reimbursement_map.target_id |
| 13 | derived | - | version_number | - | 1 AS version_number | 1 |
| 14 | derived | - | valid_from | - | NULL AS valid_ | NULL AS valid_ |
| 15 | - | - | valid_until | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | tenant_id | - | See source script | See source script |
| 18 | - | - | created_at | - | See source script | See source script |
| 19 | - | - | updated_at | - | See source script | See source script |
| 20 | - | - | archived_at | - | See source script | See source script |
| 21 | - | - | deleted_at | - | See source script | See source script |
| 22 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `shore.seafarer_reimbursements`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/reimbursement_request_item_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/reimbursement_request_item_attachments_validation.sql` if available
- Run `06-rollback/crewing/reimbursement_request_item_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
