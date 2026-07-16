# Table Mapping: consent_types → consent_types

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: consent_types
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: consent_types
- **Source Script**: `04-migration-scripts/idp/consent_types_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public.consent_types`
- **New Path**: `smac_idp_dev.public.consent_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Consent Types (`consent_types` → `consent_types`)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | COALESCE(legacy_data.id, gen_random_uuid()) as id | COALESCE(legacy_data.id, gen_random_uuid()) |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 4 | code | - | code | - | TRIM(legacy_data.code) as code | TRIM(legacy_data.code) |
| 5 | status | - | status | - | CASE WHEN legacy_data.status::text = 'Active' THEN 0 WHEN legacy_data.status::text = 'Draft' THEN 1 WHEN legacy_data.status::text = 'Inactive' THEN 2 WHEN legacy_data.status::te... | CASE WHEN legacy_data.status::text = 'Active' THEN 0 WHEN legacy_data.status::text = 'Draft' THEN 1 WHEN legacy_data.status::text = 'Inactive' THEN 2 WHEN legacy_data.status::te... |
| 6 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 7 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 8 | id | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) as audit_info | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/consent_types_migration.sql`

## Validation

- Run `05-validation/idp/consent_types_validation.sql` if available
- Run `06-rollback/idp/consent_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
