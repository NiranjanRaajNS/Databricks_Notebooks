# Table Mapping: cluster_vessels → cluster_vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: cluster_vessels
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: cluster_vessels
- **Source Script**: `04-migration-scripts/master/cluster_vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.cluster_vessels`
- **New Path**: `smac_master_migration.vessel.cluster_vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `cluster_id` and `vessel_id` via `table_mappings` lookups
- `effective_from`/`effective_to` from `vessel_fdl` dates lookup
- `vessel_revision_id` from `vessel_details.identifier`
- `DISTINCT ON (id)`; requires cluster + vessel mappings

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.cluster_vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cluster_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_cluster_id`, `new_cluster_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | Check if any mappings | `vessel_details_identifier`, `new_vessel_id`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_fdl_dates_mapping` | FK lookup | `new_cluster_id`, `vessel_details_identifier`, `effective_from_date`, `handover_date` | `migration.table_mappings` (see SQL) | `synergy_vessel` |

### `cluster_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_cluster_id, new_cluster_id
- **migration.table_mappings**: target_table=clusters

```sql
CREATE TEMP TABLE cluster_id_mapping AS
SELECT
    source_id::uuid as legacy_cluster_id,
    target_id::uuid as new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### `vessel_id_mapping`

- **Purpose**: Check if any mappings
- **Output columns**: vessel_details_identifier, new_vessel_id, new_vessel_revision_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.identifier as vessel_details_identifier,
    tm_vessel.target_id as new_vessel_id,
    vr.id as new_vessel_revision_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.source_id = vd.vessel_id::text
    AND tm_vessel.target_table = 'vessels'
    AND tm_vessel.target_db = current_database()
LEFT JOIN vessel.vessel_revisions vr
    ON vr.id = vd.identifier
WHERE tm_vessel.target_id IS NOT NULL
  AND vr.id IS NOT NULL;
```

### `vessel_fdl_dates_mapping`

- **Output columns**: new_cluster_id, vessel_details_identifier, effective_from_date, handover_date
- **migration.table_mappings**: target_table=clusters
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_fdl_dates_mapping AS
SELECT DISTINCT ON (tm_cluster.target_id, vd.identifier)
    tm_cluster.target_id AS new_cluster_id,
    vd.identifier AS vessel_details_identifier,
    vf.effective_from_date AS effective_from_date,
    vf.handover_date AS handover_date
FROM dblink('synergy_vessel',
    'SELECT cluster_id, vessel_id, effective_from_date, handover_date
     FROM public.vessel_fdl
     WHERE cluster_id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vf(
    cluster_id uuid,
    vessel_id uuid,
    effective_from_date timestamp,
    handover_date timestamp
)
LEFT JOIN migration.table_mappings tm_cluster
    ON tm_cluster.source_id = vf.cluster_id::text
    AND tm_cluster.target_table = 'clusters'
    AND tm_cluster.target_db = current_database()
LEFT JOIN dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_details WHERE identifier IS NOT NULL'
) AS vd(identifier uuid)
    ON vd.identifier = vf.vessel_id
WHERE tm_cluster.target_id IS NOT NULL
  AND vd.identifier IS NOT NULL
ORDER BY tm_cluster.target_id, vd.identifier, vf.effective_from_date DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `cluster_id` | uuid | `cluster_id` | uuid | Map via `cluster_id_mapping` | FK lookup |
| 3 | `vessel_id` | uuid | `vessel_id` | uuid | Map via `vessel_id_mapping` (vessel_details) | FK lookup |
| 4 | `—` | — | `effective_from` | date | From `vessel_fdl_dates` lookup on cluster + vessel | Derived from vessel_fdl |
| 5 | `—` | — | `effective_to` | date | From `vessel_fdl_dates.handover_date` | Derived from vessel_fdl |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 7 | `—` | — | `parent_id` | uuid | `NULL` | No parent in SAC |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` |  |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 12 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | No source equivalent |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | SAC audit_info JSON not migrated |
| 14 | `—` | — | `level` | numeric | `NULL` | Not populated |
| 15 | `vessel_id` | uuid | `vessel_revision_id` | uuid | `vessel_details.identifier` from mapping | FK to vessel revision |
| 16 | `—` | — | `tags` | text[] | `NULL` | Not populated |
| 17 | `deleted_at, status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 18 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 19 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |

**SAC columns not migrated:** `audit_info` JSONB — replaced with SMAC audit structure.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`
- `countries`
- `flags`
- `ports`
- `vessel.clusters`
- `vessel.vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cluster ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_cluster_id, new_cluster_id`
**migration.table_mappings**: `target_table='clusters'`

```sql
CREATE TEMP TABLE cluster_id_mapping AS
SELECT
    source_id::uuid as legacy_cluster_id,
    target_id::uuid as new_cluster_id
FROM migration.table_mappings
WHERE target_table = 'clusters'
  AND target_db = current_database();
```

### 2. Vessel ID Mapping
**Purpose**: Check if any mappings
**Output columns**: `vessel_details_identifier, new_vessel_id, new_vessel_revision_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.identifier as vessel_details_identifier,
    tm_vessel.target_id as new_vessel_id,
    vr.id as new_vessel_revision_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.source_id = vd.vessel_id::text
    AND tm_vessel.target_table = 'vessels'
    AND tm_vessel.target_db = current_database()
LEFT JOIN vessel.vessel_revisions vr
    ON vr.id = vd.identifier
WHERE tm_vessel.target_id IS NOT NULL
  AND vr.id IS NOT NULL;
```

### 3. Vessel Fdl Dates ID Mapping
**Output columns**: `new_cluster_id, vessel_details_identifier, effective_from_date, handover_date`
**migration.table_mappings**: `target_table='clusters'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_fdl_dates_mapping AS
SELECT DISTINCT ON (tm_cluster.target_id, vd.identifier)
    tm_cluster.target_id AS new_cluster_id,
    vd.identifier AS vessel_details_identifier,
    vf.effective_from_date AS effective_from_date,
    vf.handover_date AS handover_date
FROM dblink('synergy_vessel',
    'SELECT cluster_id, vessel_id, effective_from_date, handover_date
     FROM public.vessel_fdl
     WHERE cluster_id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vf(
    cluster_id uuid,
    vessel_id uuid,
    effective_from_date timestamp,
    handover_date timestamp
)
LEFT JOIN migration.table_mappings tm_cluster
    ON tm_cluster.source_id = vf.cluster_id::text
    AND tm_cluster.target_table = 'clusters'
    AND tm_cluster.target_db = current_database()
LEFT JOIN dblink('synergy_vessel',
    'SELECT identifier FROM public.vessel_details WHERE identifier IS NOT NULL'
) AS vd(identifier uuid)
    ON vd.identifier = vf.vessel_id
WHERE tm_cluster.target_id IS NOT NULL
  AND vd.identifier IS NOT NULL
ORDER BY tm_cluster.target_id, vd.identifier, vf.effective_from_date DESC;
```

Full migration context: `04-migration-scripts/master/cluster_vessels_migration.sql`

## Validation

- Run `05-validation/master/cluster_vessels_validation.sql` if available
- Run `06-rollback/master/cluster_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
