# Table Mapping: agent_types → agent_types

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: agent_types
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: agent_types
- **Source Script**: `04-migration-scripts/idp/agent_types_migration.sql`

- **Legacy Path**: `smac_master_migration.public.agent_types`
- **New Path**: `smac_idp_dev.public.agent_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Agent Types (`agent_types` → `agent_types`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.agent_types)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | code | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') AS code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), '') AS name | COALESCE(TRIM(legacy_data.name), '') |
| 4 | description | - | description | - | legacy_data.description AS description | legacy_data.description |
| 5 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 6 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 8 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 9 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/agent_types_migration.sql`

## Validation

- Run `05-validation/idp/agent_types_validation.sql` if available
- Run `06-rollback/idp/agent_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
