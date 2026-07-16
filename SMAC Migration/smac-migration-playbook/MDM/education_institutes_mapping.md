# Table Mapping: education_institutes → education_institutes

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: education_institutes
- **Source Script**: `04-migration-scripts/master/education_institutes_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.education_details.institute (DISTINCT)`
- **New Path**: `smac_master_migration.public.education_institutes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Education Institutes (`education_details` → `education_institutes`)

## Migration Notes

- Extract distinct institute values from education_details table
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Duplicate UUID check skipped - source table has no UUID column to preserve
- Extracts distinct institute values from education_details.institute column. Generates new UUIDs for id (no legacy UUID to preserve). Code generated from name using UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_') || '_' || UUID suffix).

## Special Considerations

- Script performs `TRUNCATE TABLE public.education_institutes` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | id | id |
| 2 | derived | - | code | - | code | code |
| 3 | derived | - | name | - | name | name |
| 4 | derived | - | tenant_id | - | tenant_id | tenant_id |
| 5 | derived | - | version | - | version | version |
| 6 | derived | - | defined_by | - | defined_by | defined_by |
| 7 | derived | - | workflow_status | - | workflow_status | workflow_status |
| 8 | derived | - | status | - | status | status |
| 9 | derived | - | created_at | - | created_at | created_at |
| 10 | derived | - | updated_at | - | updated_at | updated_at |
| 11 | derived | - | audit_info | - | audit_info | audit_info |
| 12 | derived | - | level | - | ROW_NUMBER() OVER (ORDER BY LOWER(name), LOWER(code)) - 1 as level | ROW_NUMBER() OVER (ORDER BY LOWER(name), LOWER(code)) - 1 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/education_institutes_migration.sql`

## Validation

- Run `05-validation/master/education_institutes_validation.sql` if available
- Run `06-rollback/master/education_institutes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
