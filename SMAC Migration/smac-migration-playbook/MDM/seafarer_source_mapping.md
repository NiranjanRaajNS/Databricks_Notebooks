# Table Mapping: seafarer_sources → seafarer_source

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: seafarer_sources
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: seafarer_source
- **Source Script**: `04-migration-scripts/master/seafarer_source_migration.sql`

- **Legacy Path**: `synergy_master.public.seafarer_sources`
- **New Path**: `smac_master_migration.crewing.seafarer_source`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Sources (`seafarer_sources` → `seafarer_source`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_sources to seafarer_source. Check for identifier/uuid columns and update migration script accordingly

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.seafarer_source` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | code | - | See source script | See source script |
| 3 | - | - | name | - | See source script | See source script |
| 4 | - | - | description | - | See source script | See source script |
| 5 | - | - | tenant_id | - | See source script | See source script |
| 6 | - | - | parent_id | - | See source script | See source script |
| 7 | - | - | level | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | defined_by | - | See source script | See source script |
| 10 | - | - | workflow_status | - | See source script | See source script |
| 11 | - | - | status | - | See source script | See source script |
| 12 | - | - | created_at | - | See source script | See source script |
| 13 | - | - | updated_at | - | See source script | See source script |
| 14 | - | - | deleted_at | - | See source script | See source script |
| 15 | - | - | archived_at | - | See source script | See source script |
| 16 | - | - | audit_info | - | See source script | See source script |
| 17 | - | - | tags | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/seafarer_source_migration.sql`

## Validation

- Run `05-validation/master/seafarer_source_validation.sql` if available
- Run `06-rollback/master/seafarer_source_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
