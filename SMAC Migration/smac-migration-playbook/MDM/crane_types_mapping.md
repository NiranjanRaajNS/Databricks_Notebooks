# Table Mapping: (seed data) → crane_types

## Overview
- **Legacy Database**: N/A (seed)
- **Legacy Schema**: -
- **Legacy Table**: (seed data)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: crane_types
- **Source Script**: `08-seed-data/vessel/crane_types_seed_data.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cranes (`crane_types` → `cranes`)

## Migration Notes

- If constants.sql is available, these can be replaced with psql variables
- No legacy migration script; populated via seed data SQL.

## Special Considerations

- Seed script: fixed rows inserted via VALUES (no legacy source table).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | code | - | See source script | See source script |
| 3 | - | - | name | - | See source script | See source script |
| 4 | - | - | description | - | See source script | See source script |
| 5 | - | - | level | - | See source script | See source script |
| 6 | - | - | tenant_id | - | See source script | See source script |
| 7 | - | - | parent_id | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | created_at | - | See source script | See source script |
| 10 | - | - | updated_at | - | See source script | See source script |
| 11 | - | - | deleted_at | - | See source script | See source script |
| 12 | - | - | archived_at | - | See source script | See source script |
| 13 | - | - | audit_info | - | See source script | See source script |
| 14 | - | - | tags | - | See source script | See source script |
| 15 | - | - | status | - | See source script | See source script |
| 16 | - | - | workflow_status | - | See source script | See source script |
| 17 | - | - | defined_by | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `08-seed-data/vessel/crane_types_seed_data.sql`

## Validation

- Run `05-validation/master/crane_types_validation.sql` if available
- Run `06-rollback/master/crane_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
