# Table Mapping: vessels_cranes → vessel_cranes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessels_cranes
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_cranes
- **Source Script**: `04-migration-scripts/master/vessel_cranes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessels_cranes`
- **New Path**: `smac_master_migration.vessel.vessel_cranes`

## Business Key

- **Composite Key**: (`vessel_id`, `name`)
- **Source (orchestration)**: Vessel Cranes (`vessels_cranes` → `vessel_cranes`)

## Migration Notes

- SAC `id` (bigint) → SMAC `id` via `migration.resolve_target_id()` with `p_target_id = NULL`
- `vessel_id` via `vesselsid` → `vessel_details` → vessels mapping
- `crane_type_id` via `crane` bigint → `crane_types` mapping
- `crane_capacity` stored in `audit_info.legacy_crane_capacity` — no target column
- Filter: `WHERE` valid vessel mapping in staging
- `created_at`/`updated_at` set to `NOW()` — not in SAC source
## Special Considerations

- Includes all rows (per Rule 2.6 - no deleted_at filter)
- Script performs `TRUNCATE TABLE vessel.vessel_cranes` before insert (full table reload).
- Orchestration dependencies: `vessels`, `crane_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | Check if any m | `vessel_details_id`, `vessel_legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `crane_type_id_mapping` | FK lookup | `legacy_crane_id`, `new_crane_type_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Purpose**: Check if any m
- **Output columns**: vessel_details_id, vessel_legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    tm.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vesselsid
     FROM public.vessels_cranes
     WHERE vesselsid IS NOT NULL'
) AS vc(vesselsid bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vc.vesselsid
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### `crane_type_id_mapping`

- **Output columns**: legacy_crane_id, new_crane_type_id
- **migration.table_mappings**: target_table=crane_types

```sql
CREATE TEMP TABLE crane_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_crane_id,
    target_id AS new_crane_type_id
FROM migration.table_mappings
WHERE target_table = 'crane_types'
  AND target_db = current_database()
  AND source_id ~ '^\d+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `vesselsid` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` through `vessel_details` | FK lookup |
| 3 | `—` | — | `crane_id` | uuid | `NULL` | Not in SAC source |
| 4 | `—` | — | `cranes_nos` | integer | `NULL` | Not in SAC source |
| 5 | `—` | — | `level` | integer | `NULL` | Not in SAC source |
| 6 | `crane` | bigint | `crane_type_id` | uuid | Map via `crane_type_id_mapping` → `crane_types` | FK lookup |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 8 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 9 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 10 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 11 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 12 | `—` | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 13 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 14 | `id, vesselsid, crane, crane_capacity` | bigint, numeric | `audit_info` | jsonb | `jsonb_build_object()` with legacy metadata + `legacy_crane_capacity` | No dedicated capacity column |
| 15 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 16 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status in SAC |
| 17 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not sourced from SAC |
| 18 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |

**SAC columns not migrated:** None from dblink SELECT beyond audit_info storage.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crane_types`
- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Purpose**: Check if any m
**Output columns**: `vessel_details_id, vessel_legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    tm.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vesselsid
     FROM public.vessels_cranes
     WHERE vesselsid IS NOT NULL'
) AS vc(vesselsid bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vc.vesselsid
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Crane Type ID Mapping
**Output columns**: `legacy_crane_id, new_crane_type_id`
**migration.table_mappings**: `target_table='crane_types'`

```sql
CREATE TEMP TABLE crane_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_crane_id,
    target_id AS new_crane_type_id
FROM migration.table_mappings
WHERE target_table = 'crane_types'
  AND target_db = current_database()
  AND source_id ~ '^\d+$';
```

Full migration context: `04-migration-scripts/master/vessel_cranes_migration.sql`

## Validation

- Run `05-validation/master/vessel_cranes_validation.sql` if available
- Run `06-rollback/master/vessel_cranes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
