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

- Source `synergy_training.public.recommend_training` → `public.seafarer_training_records`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`; pre-migration duplicate UUID check
- FK lookups: seafarers, vessels, `training_master`, `training_category` (by `type` name), ranks (`recommender_rank`), active `vessel_revisions` (status=5)
- `type` column used for both `training_category_id` lookup and `approval_status`
- Post-migration UPDATE: `reason_id` set to nil UUID where NULL
- `status` derived from `deleted_at` (`'Deleted'` / `'Active'`)
- Requires `seafarers`, `training_master`, `vessels`, `ranks` migrated first

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `seafarer_id` | integer | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID fallback | |
| 3 | `training_id` | uuid | `training_id` | uuid | Map via `training_id_mapping`; fallback legacy `training_id` | |
| 4 | `type` | text | `training_category_id` | uuid | Match `training_category.name`; nil UUID fallback | Same source column as `approval_status` |
| 5 | `other_training` | text | `other_training` | text | `TRIM(other_training)` | |
| 6 | `vessel_id` | integer | `vessel_id` | uuid | Map via `vessel_id_mapping` | Optional |
| 7 | `vessel_id` | integer | `vessel_revision_id` | uuid | Active revision for mapped vessel | From `vessel_revision_id_mapping` |
| 8 | `target_date`, `created_at` | timestamp with time zone | `target_date_of_training` | date | `CAST(target_date AS date)` or `created_at` | |
| 9 | `target_date`, `created_at` | timestamp with time zone | `date_of_training` | date | Same as `target_date_of_training` | |
| 10 | `expired_at` | timestamp with time zone | `expiry_date` | date | `CAST(expired_at AS date)` | |
| 11 | `status` | text | `training_status` | text | `TRIM(status)` | |
| 12 | — | — | `score` | numeric(5,2) | `NULL` | Not in SAC source |
| 13 | `recommender` | uuid | `recommended_by` | uuid | Direct copy | |
| 14 | `recommender_rank` | integer | `recommended_by_position` | uuid | Rank `identifier` lookup via `rank_id_mapping` | |
| 15 | `remarks` | text | `remarks` | text | `TRIM(remarks)` | |
| 16 | — | — | `synced_to_shore` | boolean | Hardcoded `false` | |
| 17 | — | — | `approved_by` | uuid | `NULL` | |
| 18 | `type` | text | `approval_status` | text | `TRIM(type)` | Same SAC column as `training_category_id` lookup |
| 19 | `source` | jsonb | `source` | jsonb | Direct copy | |
| 20 | `deleted_at` | timestamp with time zone | `status` | text | `'Deleted'` / `'Active'` from `deleted_at` | |
| 21 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 22 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 23 | `updated_at` | timestamp with time zone | `updated_at` | timestamp without time zone | Direct copy | |
| 24 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 25 | `deleted_at` | timestamp with time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 26 | `created_by_id`, `updated_by_id`, `deleted_by_id`, names | text | `audit_info` | jsonb | `jsonb_build_object()` standardized structure | No `legacy_id` |
| 27 | `comments` | jsonb | `comments` | text | `comments::text` | |

**SMAC columns not migrated:** `reason_id` — post-migration UPDATE sets nil UUID (not from SAC column).

**SAC columns not migrated:** `deleted_by_name` — selected but unused.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ranks`
- `seafarers`
- `training_master`
- `vessels`

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
