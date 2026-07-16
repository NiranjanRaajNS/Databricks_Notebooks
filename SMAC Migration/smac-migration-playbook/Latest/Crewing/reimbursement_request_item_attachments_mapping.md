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

- SAC `synergy_crewwage.reimbursement_request_item_attachments` (bigint `id`) → SMAC `public.seafarer_attachments`
- `id` generated via `gen_random_uuid()` per row (performance optimization — bulk mapping stored post-insert via `audit_info.legacy_id`)
- `seafarer_id` resolved by join chain: `reimbursement_request_item_id` → `migration.table_mappings` (`reimbursement_request_items` → `seafarer_reimbursements`) → `shore.seafarer_reimbursements.seafarer_id`
- `reference_entity` = `'seafarer_reimbursements'`; `reference_id` = mapped reimbursement target UUID
- `file_type` hardcoded `'Reimbursement'`; `file_path` → `file_url`; `content_type` → `file_content_type`
- `status` derived from `deleted_at`: `'Deleted'` if not null, else `'Active'`
- Batch processing (1000 rows/batch) with direct joins — no temp lookup tables
- `audit_info` via `migration.build_audit_info()` plus `legacy_id` for mapping storage
- Requires `seafarer_reimbursements` and `seafarers` migrated first

## Special Considerations

- Orchestration dependencies: `seafarer_reimbursements`, `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `gen_random_uuid()` | `legacy_id` stored in `audit_info` for bulk mapping post-insert |
| 2 | via `seafarer_reimbursements` | uuid | `seafarer_id` | uuid | `sr.seafarer_id` from join on mapped reimbursement | INNER JOIN — requires valid reimbursement + assignment |
| 3 | — | — | `file_type` | text | Hardcoded `'Reimbursement'` | SMAC attachment category |
| 4 | — | — | `file_sub_type` | text | `NULL` | Not in SAC source |
| 5 | — | — | `master_document_id` | uuid | `NULL` | Not in SAC source |
| 6 | `file_name` | text | `file_name` | text | `COALESCE(NULLIF(TRIM(file_name), ''), 'unnamed_file')` | Defaults to `'unnamed_file'` |
| 7 | `content_type` | text | `file_content_type` | text | `NULLIF(TRIM(content_type), '')` | Nullable |
| 8 | `file_size` | integer | `file_size` | bigint | `CAST(COALESCE(file_size, 0) AS bigint)` | Type widened to bigint |
| 9 | `file_path` | text | `file_url` | text | `COALESCE(NULLIF(TRIM(file_path), ''), '')` | Column rename |
| 10 | — | — | `checksum` | text | `NULL` | Not in SAC source |
| 11 | — | — | `reference_entity` | text | Hardcoded `'seafarer_reimbursements'` | Links attachment to reimbursement entity |
| 12 | `reimbursement_request_item_id` | bigint | `reference_id` | uuid | Map via `table_mappings` (`reimbursement_request_items` → `seafarer_reimbursements`) | INNER JOIN on `source_id` |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Initial version |
| 14 | — | — | `valid_from` | date | `NULL` | Not in SAC source |
| 15 | — | — | `valid_until` | date | `NULL` | Not in SAC source |
| 16 | `deleted_at` | timestamp | `status` | text | `deleted_at IS NOT NULL` → `'Deleted'`; else `'Active'` | String status |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` (batch function param) | From `constants.sql` |
| 18 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 19 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 21 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 22 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `id` | text, bigint | `audit_info` | jsonb | `migration.build_audit_info()` \|\| `jsonb_build_object('legacy_id', id::text)` | `legacy_id` enables bulk mapping storage |

**SMAC columns not migrated:** None beyond unpopulated nullable fields.

**SAC columns not migrated:** `created_by_name`, `updated_by_name`, `deleted_by_name` — not mapped to separate SMAC columns (not in attachment schema).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_reimbursements`
- `seafarers`
- `shore.seafarer_reimbursements`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/reimbursement_request_item_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/reimbursement_request_item_attachments_validation.sql` if available
- Run `06-rollback/crewing/reimbursement_request_item_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
