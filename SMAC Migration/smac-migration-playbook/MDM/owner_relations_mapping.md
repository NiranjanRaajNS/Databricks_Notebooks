# Table Mapping: vessel_registered_owners (where vessel_owner_id IS NOT NULL) → owner_relations

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_registered_owners (where vessel_owner_id IS NOT NULL)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: owner_relations
- **Source Script**: `04-migration-scripts/master/owner_relations_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_registered_owners (where vessel_owner_id IS NOT NULL)`
- **New Path**: `smac_master_migration.vessel.owner_relations`

## Business Key

- **Composite Key**: (`owner_id`, `related_owner_id`, `relation_type`)
- **Source (orchestration)**: Vessel Registered Owners (`vessel_registered_owners` → `owner_relations`)

## Migration Notes

- Migrates relationships between Registered Owner and Group Owner
- vessel_owner_id is an array, so we count array elements, not rows
- Migrates relationships between Registered Owner and Group Owner from vessel_registered_owners table. Maps owner_id => id (Registered Owner), related_owner_id => vessel_owner_id (Group Owner), relation_type => 0. Only migrates records where vessel_owner_id IS NOT NULL. Requires owners table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.owner_relations` before insert (full table reload).
- Orchestration dependencies: `owners`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `registered_owner_id_mapping` | FK lookup | `legacy_owner_id`, `new_owner_id` | `?.?.vessel_registered_owners` → `?.?.owners` | - |
| `group_owner_id_mapping` | FK lookup | `legacy_vessel_owner_id`, `new_owner_id` | `?.?.vessel_owners` → `?.?.owners` | - |

### `registered_owner_id_mapping`

- **Output columns**: legacy_owner_id, new_owner_id
- **migration.table_mappings**: source_table=vessel_registered_owners, target_table=owners

```sql
CREATE TEMP TABLE IF NOT EXISTS registered_owner_id_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table ='vessel_registered_owners'
  AND target_db = current_database();
```

### `group_owner_id_mapping`

- **Output columns**: legacy_vessel_owner_id, new_owner_id
- **migration.table_mappings**: source_table=vessel_owners, target_table=owners

```sql
CREATE TEMP TABLE IF NOT EXISTS group_owner_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
AND source_table ='vessel_owners'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | DISTINCT ON (resolved_id) resolved_id as id | DISTINCT ON (resolved_id) resolved_id |
| 2 | derived | - | code | - | resolved_code as code | resolved_code |
| 3 | derived | - | name | - | resolved_name as name | resolved_name |
| 4 | derived | - | description | - | resolved_description as description | resolved_description |
| 5 | derived | - | owner_id | - | resolved_owner_id as owner_id | resolved_owner_id |
| 6 | derived | - | related_owner_id | - | resolved_related_owner_id as related_owner_id | resolved_related_owner_id |
| 7 | derived | - | relation_type | - | resolved_relation_type as relation_type | resolved_relation_type |
| 8 | derived | - | tenant_id | - | resolved_tenant_id as tenant_id | resolved_tenant_id |
| 9 | derived | - | parent_id | - | resolved_parent_id as parent_id | resolved_parent_id |
| 10 | derived | - | level | - | resolved_level as level | resolved_level |
| 11 | derived | - | version | - | resolved_version as version | resolved_version |
| 12 | derived | - | defined_by | - | resolved_defined_by as defined_by | resolved_defined_by |
| 13 | derived | - | workflow_status | - | resolved_workflow_status as workflow_status | resolved_workflow_status |
| 14 | derived | - | status | - | resolved_status as status | resolved_status |
| 15 | derived | - | created_at | - | resolved_created_at as created_at | resolved_created_at |
| 16 | derived | - | updated_at | - | resolved_updated_at as updated_at | resolved_updated_at |
| 17 | derived | - | deleted_at | - | resolved_deleted_at as deleted_at | resolved_deleted_at |
| 18 | derived | - | archived_at | - | resolved_archived_at as archived_at | resolved_archived_at |
| 19 | derived | - | audit_info | - | resolved_audit_info as audit_info | resolved_audit_info |
| 20 | derived | - | tags | - | resolved_tags as tags | resolved_tags |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Registered Owner ID Mapping
**Output columns**: `legacy_owner_id, new_owner_id`
**migration.table_mappings**: `vessel_registered_owners` → `owners`

```sql
CREATE TEMP TABLE IF NOT EXISTS registered_owner_id_mapping AS
SELECT
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table ='vessel_registered_owners'
  AND target_db = current_database();
```

### 2. Group Owner ID Mapping
**Output columns**: `legacy_vessel_owner_id, new_owner_id`
**migration.table_mappings**: `vessel_owners` → `owners`

```sql
CREATE TEMP TABLE IF NOT EXISTS group_owner_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
AND source_table ='vessel_owners'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/owner_relations_migration.sql`

## Validation

- Run `05-validation/master/owner_relations_validation.sql` if available
- Run `06-rollback/master/owner_relations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
