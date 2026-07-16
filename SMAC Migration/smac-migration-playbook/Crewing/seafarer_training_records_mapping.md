# Table Mapping: recommend_training → seafarer_training_records

## Overview
- **Legacy Database**: synergy_training
- **Legacy Schema**: public
- **Legacy Table**: recommend_training
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_training_records
- **Source Script**: `04-migration-scripts/crewing/seafarer_training_records_migration.sql`

- **Legacy Path**: `synergy_training.public.recommend_training`
- **New Path**: `smac_crewing_migration.public.seafarer_training_records`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Training Records (`recommend_training` → `seafarer_training_records`)

## Migration Notes

- Migrates recommend_training to seafarer_training_records preserving UUID id. Maps seafarer_id (integer) to UUID via migration.table_mappings from smac_crewing_migration. Maps vessel_id (integer) to UUID via migration.table_mappings from smac_master_migration. Derives training_category_id from training_master table via training_id. Maps recommender_rank (integer) to recommended_by_position (uuid) via ranks mapping. Converts target_date and expired_at from timestamp with time zone to date. Maps status based on deleted_at. Requires seafarers, training_master, vessels, and ranks tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_training_records` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `training_master`, `vessels`, `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `training_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `training_category_id_mapping` | FK lookup | `type_name`, `training_category_id` | - | `smac_master_migration` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `training_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE training_id_mapping AS
SELECT
    source_id::uuid as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''training_master'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `training_category_id_mapping`

- **Output columns**: type_name, training_category_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE training_category_id_mapping AS
SELECT
    UPPER(TRIM(tc.name)) as type_name,
    tc.id as training_category_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.training_category'
) AS tc(id uuid, name text)
WHERE tc.name IS NOT NULL;
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint as legacy_id, identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS t(id bigint, identifier uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_training'::VARCHAR(100), 'public'::VARCHAR(100), 'recommend_training'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | training_id | - | training_id | - | COALESCE( training_map.new_id, legacy_data.training_id ) AS training_id | COALESCE( training_map.new_id, legacy_data.training_id ) |
| 4 | derived | - | training_category_id | - | COALESCE( training_category_map.training_category_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS training_category_id | COALESCE( training_category_map.training_category_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 5 | other_training | - | other_training | - | TRIM(legacy_data.other_training) AS other_training | TRIM(legacy_data.other_training) |
| 6 | derived | - | vessel_id | - | vessel_map.new_id AS vessel_id | vessel_map.new_id |
| 7 | derived | - | vessel_revision_id | - | vessel_revision_map.active_revision_id AS vessel_revision_id | vessel_revision_map.active_revision_id |
| 8 | target_date, created_at | - | target_date_of_training | - | COALESCE( CAST(legacy_data.target_date AS date), CAST(legacy_data.created_at AS date) ) AS target_date_of_training | COALESCE( CAST(legacy_data.target_date AS date), CAST(legacy_data.created_at AS date) ) |
| 9 | target_date, created_at | - | date_of_training | - | COALESCE( CAST(legacy_data.target_date AS date), CAST(legacy_data.created_at AS date) ) AS date_of_training | COALESCE( CAST(legacy_data.target_date AS date), CAST(legacy_data.created_at AS date) ) |
| 10 | expired_at | - | expiry_date | - | CAST(legacy_data.expired_at AS date) AS expiry_date | CAST(legacy_data.expired_at AS date) |
| 11 | status | - | training_status | - | TRIM(legacy_data.status) AS training_status | TRIM(legacy_data.status) |
| 12 | - | - | score | - | NULL | NULL::numeric(5,2) |
| 13 | recommender | - | recommended_by | - | legacy_data.recommender AS recommended_by | legacy_data.recommender |
| 14 | derived | - | recommended_by_position | - | rank_map.new_id AS recommended_by_position | rank_map.new_id |
| 15 | remarks | - | remarks | - | TRIM(legacy_data.remarks) AS remarks | TRIM(legacy_data.remarks) |
| 16 | derived | - | synced_to_shore | - | false AS synced_to_shore | false |
| 17 | - | - | approved_by | - | NULL | NULL::uuid |
| 18 | type | - | approval_status | - | TRIM(legacy_data.type) AS approval_status | TRIM(legacy_data.type) |
| 19 | source | - | source | - | legacy_data.source AS source | legacy_data.source |
| 20 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted' ELSE 'Active' END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted' ELSE 'Active' END |
| 21 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 22 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 23 | updated_at | - | updated_at | - | legacy_data.updated_at AS updated_at | legacy_data.updated_at |
| 24 | - | - | archived_at | - | NULL | NULL::timestamp |
| 25 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 26 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |
| 27 | comments | - | comments | - | COALESCE(legacy_data.comments::text, NULL) AS comments | COALESCE(legacy_data.comments::text, NULL) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Training ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE training_id_mapping AS
SELECT
    source_id::uuid as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''training_master'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 4. Training Category ID Mapping
**Output columns**: `type_name, training_category_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE training_category_id_mapping AS
SELECT
    UPPER(TRIM(tc.name)) as type_name,
    tc.id as training_category_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.training_category'
) AS tc(id uuid, name text)
WHERE tc.name IS NOT NULL;
```

### 5. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 6. Rank ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint as legacy_id, identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS t(id bigint, identifier uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_training_records_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_training_records_validation.sql` if available
- Run `06-rollback/crewing/seafarer_training_records_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
