# Table Mapping: vessel_details → vessel_revision_owners

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revision_owners
- **Source Script**: `04-migration-scripts/master/vessel_revision_owners_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details`
- **New Path**: `smac_master_migration.vessel.vessel_revision_owners`

## Business Key

- **Composite Key**: (`vessel_id`, `owner_id`)
- **Source (orchestration)**: Vessel Revision Owners (`vessel_details` → `vessel_revision_owners`)

## Migration Notes

- Creates rows for each owner_id column in vessel_details (owner_id, register_owner_id, bare_boat_owner_id, beneficiary_owner_id)
- Maps bigint owner_id to UUID via migration.table_mappings (owners)
- Maps bigint vessel_id to UUID via migration.table_mappings (vessels)
- Retrieves name and code from owners table based on mapped owner_id
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessels and owners tables to be migrated first
- Creates rows for each owner_id column in vessel_details (owner_id, register_owner_id). Maps bigint owner_id to UUID via migration.table_mappings (owners). Maps bigint vessel_id to UUID via migration.table_mappings (vessels). Retrieves name and code from owners table based on mapped owner_id. Requires vessels and owners tables to be migrated first.

## Special Considerations

- Uses migration.resolve_target_id() for idempotent UUID generation (unpivot operation - uses composite source_id)
- Script performs `TRUNCATE TABLE vessel.vessel_revision_owners` before insert (full table reload).
- Orchestration dependencies: `vessels`, `owners`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `group_owners_mapping` | FK lookup | `legacy_owner_id`, `new_owner_id`, `owner_type_id` | `?.?.vessel_owners` → `?.?.owners` | - |
| `registered_owners_mapping` | FK lookup | `legacy_owner_id`, `new_owner_id`, `owner_type_id` | `?.?.vessel_registered_owners` → `?.?.owners` | - |
| `bare_boat_owners_mapping` | FK lookup | `legacy_owner_uuid`, `new_owner_id`, `owner_type_id` | `?.?.vessel_bare_boat_owner` → `?.?.owners` | - |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `group_owners_mapping`

- **Output columns**: legacy_owner_id, new_owner_id, owner_type_id
- **migration.table_mappings**: source_table=vessel_owners, target_table=owners

```sql
CREATE TEMP TABLE IF NOT EXISTS group_owners_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id,
    current_setting('migration.group_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_owners';
```

### `registered_owners_mapping`

- **Output columns**: legacy_owner_id, new_owner_id, owner_type_id
- **migration.table_mappings**: source_table=vessel_registered_owners, target_table=owners

```sql
CREATE TEMP TABLE IF NOT EXISTS registered_owners_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id,
    current_setting('migration.registered_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_registered_owners';
```

### `bare_boat_owners_mapping`

- **Output columns**: legacy_owner_uuid, new_owner_id, owner_type_id
- **migration.table_mappings**: source_table=vessel_bare_boat_owner, target_table=owners

```sql
CREATE TEMP TABLE IF NOT EXISTS bare_boat_owners_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_owner_uuid,
    target_id AS new_owner_id,
    current_setting('migration.bare_boat_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_bare_boat_owner'
  AND source_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE IF NOT EXISTS vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | DISTINCT ON (resolved_id) resolved_id as id | DISTINCT ON (resolved_id) resolved_id |
| 2 | derived | - | vessel_revision_id | - | resolved_vessel_revision_id as vessel_revision_id | resolved_vessel_revision_id |
| 3 | derived | - | vessel_id | - | resolved_vessel_id as vessel_id | resolved_vessel_id |
| 4 | derived | - | owner_id | - | resolved_owner_id as owner_id | resolved_owner_id |
| 5 | derived | - | owner_type_id | - | resolved_owner_type_id as owner_type_id | resolved_owner_type_id |
| 6 | derived | - | level | - | resolved_level as level | resolved_level |
| 7 | derived | - | start_date | - | resolved_start_date as start_date | resolved_start_date |
| 8 | derived | - | end_date | - | resolved_end_date as end_date | resolved_end_date |
| 9 | derived | - | tenant_id | - | resolved_tenant_id as tenant_id | resolved_tenant_id |
| 10 | derived | - | parent_id | - | resolved_parent_id as parent_id | resolved_parent_id |
| 11 | derived | - | version | - | resolved_version as version | resolved_version |
| 12 | derived | - | created_at | - | resolved_created_at as created_at | resolved_created_at |
| 13 | derived | - | updated_at | - | resolved_updated_at as updated_at | resolved_updated_at |
| 14 | derived | - | deleted_at | - | resolved_deleted_at as deleted_at | resolved_deleted_at |
| 15 | derived | - | archived_at | - | resolved_archived_at as archived_at | resolved_archived_at |
| 16 | derived | - | audit_info | - | resolved_audit_info as audit_info | resolved_audit_info |
| 17 | derived | - | tags | - | resolved_tags as tags | resolved_tags |
| 18 | derived | - | status | - | resolved_status as status | resolved_status |
| 19 | derived | - | workflow_status | - | resolved_workflow_status as workflow_status | resolved_workflow_status |
| 20 | derived | - | defined_by | - | resolved_defined_by as defined_by | resolved_defined_by |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Group Owners ID Mapping
**Output columns**: `legacy_owner_id, new_owner_id, owner_type_id`
**migration.table_mappings**: `vessel_owners` → `owners`

```sql
CREATE TEMP TABLE IF NOT EXISTS group_owners_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id,
    current_setting('migration.group_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_owners';
```

### 2. Registered Owners ID Mapping
**Output columns**: `legacy_owner_id, new_owner_id, owner_type_id`
**migration.table_mappings**: `vessel_registered_owners` → `owners`

```sql
CREATE TEMP TABLE IF NOT EXISTS registered_owners_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id,
    current_setting('migration.registered_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_registered_owners';
```

### 3. Bare Boat Owners ID Mapping
**Output columns**: `legacy_owner_uuid, new_owner_id, owner_type_id`
**migration.table_mappings**: `vessel_bare_boat_owner` → `owners`

```sql
CREATE TEMP TABLE IF NOT EXISTS bare_boat_owners_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_owner_uuid,
    target_id AS new_owner_id,
    current_setting('migration.bare_boat_owner_type_id')::uuid AS owner_type_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND target_db = current_database()
  AND source_table = 'vessel_bare_boat_owner'
  AND source_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### 4. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE IF NOT EXISTS vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_revision_owners_migration.sql`

## Validation

- Run `05-validation/master/vessel_revision_owners_validation.sql` if available
- Run `06-rollback/master/vessel_revision_owners_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
