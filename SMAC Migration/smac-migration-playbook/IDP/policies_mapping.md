# Table Mapping: access_policies → policies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: access_policies
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: policies
- **Source Script**: `04-migration-scripts/idp/policies_migration.sql`

- **Legacy Path**: `synergy_master.public.access_policies`
- **New Path**: `smac_idp_dev.public.policies`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Policies (`access_policies` → `policies`)

## Special Considerations

- Script performs `TRUNCATE TABLE public.policies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | name | - | id | - | DISTINCT ON (TRIM(UPPER(legacy_data.name))) gen_random_uuid() as id | DISTINCT ON (TRIM(UPPER(legacy_data.name))) gen_random_uuid() |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 4 | derived | - | policy_type | - | 'DEFAULT' as policy_type | 'DEFAULT' |
| 5 | derived | - | conditions | - | NULL as conditions | NULL |
| 6 | name | - | code | - | LEFT(UPPER(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g')), 50) as code | LEFT(UPPER(REGEXP_REPLACE(TRIM(legacy_data.name), '[^A-Za-z0-9]', '_', 'g')), 50) |
| 7 | derived | - | company_id | - | NULL as company_id | NULL |
| 8 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) as created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) as updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 11 | deleted_at | - | deleted_at | - | COALESCE(legacy_data.deleted_at AT TIME ZONE 'UTC', NULL) as deleted_at | COALESCE(legacy_data.deleted_at AT TIME ZONE 'UTC', NULL) |
| 12 | id, name | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |
| 13 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 14 | derived | - | status | - | 0 as status | 0 |
| 15 | derived | - | policy_level | - | 0 as policy_level | 0 |
| 16 | derived | - | is_system_defined | - | false as is_system_defined | false |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/policies_migration.sql`

## Validation

- Run `05-validation/idp/policies_validation.sql` if available
- Run `06-rollback/idp/policies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
