# Table Mapping: agents → agents

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: agents
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: agents
- **Source Script**: `04-migration-scripts/idp/agents_migration.sql`

- **Legacy Path**: `smac_master_migration.public.agents`
- **New Path**: `smac_idp_dev.public.agents`

## Business Key

- **Business Key**: `agent_code`
- **Source (orchestration)**: Agents (`agents` → `agents`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.agents)

## Special Considerations

- Orchestration dependencies: `agent_types`, `countries`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | legacy_data.id AS id | legacy_data.id |
| 2 | code | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') AS code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), '') |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), '') AS name | COALESCE(TRIM(legacy_data.name), '') |
| 4 | description | - | description | - | legacy_data.description AS description | legacy_data.description |
| 5 | global_agent | - | global_agent | - | COALESCE(legacy_data.global_agent, false) AS global_agent | COALESCE(legacy_data.global_agent, false) |
| 6 | country_id | - | country_id | - | legacy_data.country_id AS country_id | legacy_data.country_id |
| 7 | agent_type_id | - | agent_type_id | - | legacy_data.agent_type_id AS agent_type_id | legacy_data.agent_type_id |
| 8 | phone_number | - | phone_number | - | legacy_data.phone_number AS phone_number | legacy_data.phone_number |
| 9 | email | - | email | - | legacy_data.email AS email | legacy_data.email |
| 10 | address | - | address | - | legacy_data.address AS address | legacy_data.address |
| 11 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 12 | status | - | status | - | COALESCE(legacy_data.status, 0) AS status | COALESCE(legacy_data.status, 0) |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(legacy_data.updated_at AT TIME ZONE 'UTC', legacy_data.created_at AT TIME ZONE 'UTC', NOW()) |
| 15 | audit_info | - | audit_info | - | COALESCE(legacy_data.audit_info, '{}'::jsonb) AS audit_info | COALESCE(legacy_data.audit_info, '{}'::jsonb) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/agents_migration.sql`

## Validation

- Run `05-validation/idp/agents_validation.sql` if available
- Run `06-rollback/idp/agents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
