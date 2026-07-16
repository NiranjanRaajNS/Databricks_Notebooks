# Table Mapping: nationalities → nationalities

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: nationalities
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: nationalities
- **Source Script**: `04-migration-scripts/idp/nationalities_migration.sql`

- **Legacy Path**: `smac_master_migration.public.nationalities`
- **New Path**: `smac_idp_dev.public.nationalities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Nationalities (`nationalities` → `nationalities`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.nationalities)

## Special Considerations

- Orchestration dependencies: `countries`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | name | - | name | - | COALESCE(TRIM(legacy_data.name), '') AS name | COALESCE(TRIM(legacy_data.name), '') |
| 3 | code | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') AS code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') |
| 4 | description | - | description | - | legacy_data.description AS description | legacy_data.description |
| 5 | country_id | - | country_id | - | legacy_data.country_id AS country_id | legacy_data.country_id |
| 6 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 7 | parent_id | - | parent_id | - | legacy_data.parent_id AS parent_id | legacy_data.parent_id |
| 8 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 9 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 10 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 11 | archived_at | - | archived_at | - | legacy_data.archived_at AS archived_at | legacy_data.archived_at |
| 12 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |
| 13 | tags | - | tags | - | COALESCE(legacy_data.tags, ARRAY[]::text[]) AS tags | COALESCE(legacy_data.tags, ARRAY[]::text[]) |
| 14 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/nationalities_migration.sql`

## Validation

- Run `05-validation/idp/nationalities_validation.sql` if available
- Run `06-rollback/idp/nationalities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
