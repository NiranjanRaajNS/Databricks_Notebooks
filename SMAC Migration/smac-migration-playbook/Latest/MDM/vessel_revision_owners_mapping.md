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

- Source: `synergy_vessel.public.vessel_details` unpivoted by owner column (3 branches)
- Branches: `owner_id` (GRP), `register_owner_id` (REG), `bare_boat_owner_id` (CSE)
- SAC `id` + owner column → composite `source_id` for `migration.resolve_target_id()`
- `beneficiary_owner_id` mentioned in header but NOT migrated (no UNION branch)
- `owner_id` mapped per type via group/registered/bare-boat owner lookups
- `owner_type_id` from session variables set from `vessel.owner_types`
- Filter per branch: respective owner column IS NOT NULL
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
| 1 | `id, owner column` | bigint, bigint/uuid | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `id|owner_column_name` | One row per owner type |
| 2 | `identifier` | uuid | `vessel_revision_id` | uuid | Direct copy of `identifier` | FK to vessel_revisions |
| 3 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` | FK lookup |
| 4 | `owner_id, register_owner_id, bare_boat_owner_id` | bigint/uuid | `owner_id` | uuid | Per-branch mapping: group/registered/bare-boat owners or direct UUID | FK lookup |
| 5 | `owner column type` | — | `owner_type_id` | uuid | GRP/REG/CSE from `vessel.owner_types` session vars | Derived per branch |
| 6 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 7 | `—` | — | `start_date` | timestamp without time zone | `NULL` | Not in SAC source |
| 8 | `—` | — | `end_date` | timestamp without time zone | `NULL` | Not in SAC source |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 10 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 11 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 12 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 13 | `updated_at, created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Fallback chain |
| 14 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not populated from SAC |
| 15 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with NULL user fields | Standardized SMAC structure |
| 17 | `owner column name` | — | `tags` | text[] | `ARRAY[owner_column_name]` | Identifies source column |
| 18 | `—` | — | `status` | integer | Hardcoded `0` (Active) | Not derived from SAC status |
| 19 | `—` | — | `workflow_status` | integer | Hardcoded `2` (Approved) | Not sourced from SAC |
| 20 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |

**SAC columns not migrated:** `beneficiary_owner_id` — no UNION branch in migration script.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `owners`
- `vessels`

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
