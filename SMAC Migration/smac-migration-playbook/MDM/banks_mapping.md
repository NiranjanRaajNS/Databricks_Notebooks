# Table Mapping: banks → banks

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: banks
- **Source Script**: `04-migration-scripts/master/banks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.bank_details.bank_name (distinct values)`
- **New Path**: `smac_master_migration.public.banks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Bank Details (`bank_details` → `banks`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Distinct values from bank_details.bank_name

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE public.banks` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | COALESCE(uuid, gen_random_uuid()) as id | COALESCE(uuid, gen_random_uuid()) |
| 2 | derived | - | code | - | COALESCE(NULLIF(TRIM(ifsc_code), ''), UPPER(REGEXP_REPLACE(TRIM(bank_name), '[^A-Za-z0-9]', '_', 'g'))) as code | COALESCE(NULLIF(TRIM(ifsc_code), ''), UPPER(REGEXP_REPLACE(TRIM(bank_name), '[^A-Za-z0-9]', '_', 'g'))) |
| 3 | derived | - | name | - | TRIM(bank_name) as name | TRIM(bank_name) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 10 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 11 | derived | - | status | - | 0 as status | 0 |
| 12 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 13 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 14 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 15 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 16 | derived | - | tags | - | ARRAY[]::text[] as tags | ARRAY[]::text[] |
| 17 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/banks_migration.sql`

## Validation

- Run `05-validation/master/banks_validation.sql` if available
- Run `06-rollback/master/banks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
