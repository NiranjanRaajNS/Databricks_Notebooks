# Table Mapping: on_boarding_preplannings → on_boarding_preplannings

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: on_boarding_preplannings
- **Source Script**: `04-migration-scripts/crewing/on_boarding_preplannings_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: On Boarding Preplannings (`on_boarding_preplannings` → `on_boarding_preplannings`)

## Migration Notes

- Migrates on_boarding_preplannings table. Generates new UUIDs for id column (source id is bigint, target id is uuid). Section_id mapping: match on_boarding_preplannings.section_id (bigint) with enum.sectionidentifiers.id (bigint) and get identifier (uuid) from enum.sectionidentifiers.identifier. Legacy id stored in audit_info.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.on_boarding_preplannings` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | section_id | - | See source script | See source script |
| 3 | - | - | section_code | - | See source script | See source script |
| 4 | - | - | field | - | See source script | See source script |
| 5 | - | - | field_options | - | See source script | See source script |
| 6 | - | - | is_mandatory | - | See source script | See source script |
| 7 | - | - | level | - | See source script | See source script |
| 8 | - | - | tenant_id | - | See source script | See source script |
| 9 | - | - | version | - | See source script | See source script |
| 10 | - | - | defined_by | - | See source script | See source script |
| 11 | - | - | workflow_status | - | See source script | See source script |
| 12 | - | - | status | - | See source script | See source script |
| 13 | - | - | created_at | - | See source script | See source script |
| 14 | - | - | updated_at | - | See source script | See source script |
| 15 | - | - | deleted_at | - | See source script | See source script |
| 16 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/on_boarding_preplannings_migration.sql`

## Validation

- Run `05-validation/crewing/on_boarding_preplannings_validation.sql` if available
- Run `06-rollback/crewing/on_boarding_preplannings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
