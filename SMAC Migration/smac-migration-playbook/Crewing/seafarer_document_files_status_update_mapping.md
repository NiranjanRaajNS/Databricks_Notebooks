# Table Mapping: seafarer_document_files_status_update → seafarer_document_files_status_update

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_document_files_status_update
- **Source Script**: `04-migration-scripts/crewing/seafarer_document_files_status_update_migration.sql`


## Migration Notes

- Post-migration update: Normalizes status to enum text (Active=0, Draft=1, Inactive=2, Deleted=3, Archived=4). Converts integer columns to text when needed. Must run AFTER seafarer_document_files migration.

## Special Considerations

- Orchestration dependencies: `seafarer_document_files`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| - | - | - | - | - | - | No INSERT mapping found; see source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_document_files_status_update_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_document_files_status_update_validation.sql` if available
- Run `06-rollback/crewing/seafarer_document_files_status_update_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
