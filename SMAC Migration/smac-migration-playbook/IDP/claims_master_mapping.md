# Table Mapping: "ClaimTypeMaster" → claims_master

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "ClaimTypeMaster"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: claims_master
- **Source Script**: `04-migration-scripts/idp/claims_master_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."ClaimTypeMaster"`
- **New Path**: `smac_idp_dev.public.claims_master`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Claim Type Master (`ClaimTypeMaster` → `claims_master`)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | COALESCE(legacy_data.id, nextval(pg_get_serial_sequence('public.claims_master', 'id'))) as id | COALESCE(legacy_data.id, nextval(pg_get_serial_sequence('public.claims_master', 'id'))) |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 4 | required | - | required | - | COALESCE(legacy_data.required, false) as required | COALESCE(legacy_data.required, false) |
| 5 | user_editable | - | user_editable | - | COALESCE(legacy_data.user_editable, true) as user_editable | COALESCE(legacy_data.user_editable, true) |
| 6 | display_name | - | display_name | - | TRIM(legacy_data.display_name) as display_name | TRIM(legacy_data.display_name) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/claims_master_migration.sql`

## Validation

- Run `05-validation/idp/claims_master_validation.sql` if available
- Run `06-rollback/idp/claims_master_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
