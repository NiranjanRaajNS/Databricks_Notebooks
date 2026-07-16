# Table Mapping: endpoint_authorizations → endpoint_authorizations

## Overview
- **Legacy Database**: smac_base_database
- **Legacy Schema**: public
- **Legacy Table**: endpoint_authorizations
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: endpoint_authorizations
- **Source Script**: `04-migration-scripts/idp/endpoint_authorizations_migration.sql`

- **Legacy Path**: `smac_base_database.public.endpoint_authorizations`
- **New Path**: `smac_idp_dev.public.endpoint_authorizations`

## Business Key

- **Composite Key**: (`endpoint_id`, `claim_id`, `policy_id`)
- **Source (orchestration)**: Endpoint Authorizations (Base Database) (`endpoint_authorizations` → `endpoint_authorizations`)

## Migration Notes

- Source and target schemas are identical, preserving UUIDs from source
- Migrates endpoint_authorizations from smac_base_database. Source and target schemas are identical, preserving UUIDs from source. Requires endpoints table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.endpoint_authorizations` before insert (full table reload).
- Orchestration dependencies: `endpoints`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `endpoint_id_mapping` | FK lookup | `legacy_endpoint_id`, `new_endpoint_id` | `migration.table_mappings` (see SQL) | - |

### `endpoint_id_mapping`

- **Output columns**: legacy_endpoint_id, new_endpoint_id
- **migration.table_mappings**: target_table=endpoints

```sql
CREATE TEMP TABLE IF NOT EXISTS endpoint_id_mapping AS
SELECT
    source_id::uuid AS legacy_endpoint_id,
    target_id AS new_endpoint_id
FROM migration.table_mappings
WHERE target_table = 'endpoints'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'smac_base_database'::VARCHAR(100), 'public'::VARCHAR(100), 'endpoint_authorizations'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | endpoint_id | - | endpoint_id | - | COALESCE(ep_map.new_endpoint_id, legacy_data.endpoint_id) AS endpoint_id | COALESCE(ep_map.new_endpoint_id, legacy_data.endpoint_id) |
| 3 | claim_id | - | claim_id | - | legacy_data.claim_id | legacy_data.claim_id |
| 4 | policy_id | - | policy_id | - | legacy_data.policy_id | legacy_data.policy_id |
| 5 | company_id | - | company_id | - | legacy_data.company_id | legacy_data.company_id |
| 6 | archived_at | - | archived_at | - | legacy_data.archived_at | legacy_data.archived_at |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 9 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 10 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 11 | tenant_id | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(legacy_data.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 12 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 ELSE legacy_data.status END |
| 13 | parent_id | - | parent_id | - | legacy_data.parent_id | legacy_data.parent_id |
| 14 | tags | - | tags | - | legacy_data.tags | legacy_data.tags |
| 15 | workflow_status | - | workflow_status | - | COALESCE(legacy_data.workflow_status, 0) AS workflow_status | COALESCE(legacy_data.workflow_status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Endpoint ID Mapping
**Output columns**: `legacy_endpoint_id, new_endpoint_id`
**migration.table_mappings**: `target_table='endpoints'`

```sql
CREATE TEMP TABLE IF NOT EXISTS endpoint_id_mapping AS
SELECT
    source_id::uuid AS legacy_endpoint_id,
    target_id AS new_endpoint_id
FROM migration.table_mappings
WHERE target_table = 'endpoints'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/endpoint_authorizations_migration.sql`

## Validation

- Run `05-validation/idp/endpoint_authorizations_validation.sql` if available
- Run `06-rollback/idp/endpoint_authorizations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
