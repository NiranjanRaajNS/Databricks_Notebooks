# Table Mapping: service_types → service_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: service_types
- **Source Script**: `04-migration-scripts/master/service_types_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `service_types`)

## Migration Notes

- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Special Considerations

- Script performs `TRUNCATE TABLE public.service_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | code | - | See source script | See source script |
| 3 | - | - | name | - | See source script | See source script |
| 4 | - | - | description | - | See source script | See source script |
| 5 | - | - | tenant_id | - | See source script | See source script |
| 6 | - | - | version | - | See source script | See source script |
| 7 | - | - | created_at | - | See source script | See source script |
| 8 | - | - | updated_at | - | See source script | See source script |
| 9 | - | - | deleted_at | - | See source script | See source script |
| 10 | - | - | archived_at | - | See source script | See source script |
| 11 | - | - | audit_info | - | See source script | See source script |
| 12 | - | - | max_company_count | - | See source script | See source script |
| 13 | - | - | req_in_vessel_creation | - | See source script | See source script |
| 14 | - | - | level | - | See source script | See source script |
| 15 | - | - | tags | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | workflow_status | - | See source script | See source script |
| 18 | - | - | defined_by | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/service_types_migration.sql`

## Validation

- Run `05-validation/master/service_types_validation.sql` if available
- Run `06-rollback/master/service_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
