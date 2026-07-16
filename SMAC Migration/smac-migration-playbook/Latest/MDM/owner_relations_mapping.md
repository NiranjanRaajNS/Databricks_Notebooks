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

- Source: `synergy_vessel.public.vessel_registered_owners` (where `vessel_owner_id` array not null) → `vessel.owner_relations`
- Unnests `vessel_owner_id` bigint[] — one row per array element
- Composite source_id: `id|owner_id|array_idx` via `resolve_target_id()`; `p_target_id = NULL`
- `registered_owner_id_mapping` (source=vessel_registered_owners) + `group_owner_id_mapping` (source=vessel_owners)
- Filter: both owner FK mappings must exist
- `relation_type` hardcoded `0`
- `status` hardcoded Active (0)

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
| 1 | `id, vessel_owner_id[], array_idx` | bigint, bigint[], integer | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `id|element|idx`; `p_target_id = NULL` |  |
| 2 | `registered_owner.name` | text | `code` | text | `generate_meaningful_code(TRIM(name), gen_random_uuid()::text)` | From joined owner |
| 3 | `registered_owner.name` | text | `name` | text | `TRIM(registered_owner.name)` |  |
| 4 | `—` | — | `description` | text | Hardcoded `'Relationship between Registered Owner and Group Owner'` |  |
| 5 | `id` | bigint | `owner_id` | uuid | Map via `registered_owner_id_mapping` | FK lookup |
| 6 | `vessel_owner_id[] element` | bigint | `related_owner_id` | uuid | Map via `group_owner_id_mapping` | FK lookup |
| 7 | `—` | — | `relation_type` | integer | Hardcoded `0` |  |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 9 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 10 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 11 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 12 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 13 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 14 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 15 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 16 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` |  |
| 17 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 18 | `—` | — | `archived_at` | timestamptz | `NULL` |  |
| 19 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 20 | `—` | — | `tags` | text[] | `ARRAY['OWNER_RELATION']` |  |

**SAC columns not migrated:** Other vessel_registered_owners columns.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `owners`

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
