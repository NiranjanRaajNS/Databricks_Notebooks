# Table Mapping: matching_part_count → matching_part_count

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: matching_part_count
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: matching_part_count
- **Source Script**: `04-migration-scripts/crewing/matching_part_count_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.matching_part_count`
- **New Path**: `smac_crewing_migration.public.matching_part_count`

## Business Key

- **Business Key**: `count`
- **Source (orchestration)**: Matching Part Count (`matching_part_count` → `matching_part_count`)

## Migration Notes

- Simple single-column table, direct copy
- Migrates matching_part_count table. Simple single-column table, direct copy of count value. No foreign key dependencies or data transformations required.

## Special Considerations

- Script performs `TRUNCATE TABLE public.matching_part_count` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| - | - | - | - | - | - | No INSERT mapping found; see source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/matching_part_count_migration.sql`

## Validation

- Run `05-validation/crewing/matching_part_count_validation.sql` if available
- Run `06-rollback/crewing/matching_part_count_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
