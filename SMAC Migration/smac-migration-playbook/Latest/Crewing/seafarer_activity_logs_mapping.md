# Table Mapping: seafarer_activity_logs → seafarer_activity_logs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_activity_logs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_activity_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_activity_logs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_activity_logs`
- **New Path**: `smac_crewing_migration.public.seafarer_activity_logs`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Activity Logs (`seafarer_activity_logs` → `seafarer_activity_logs`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_id`, `type_id`, `sub_type_id` copied directly (already uuid in SAC)
- `vessel_id` (bigint) mapped via `vessels_id_mapping` from `smac_master_migration`; `vessel_name` looked up from `vessel.vessels`
- `rank_id` (bigint) mapped via `ranks_id_mapping` using SAC `synergy_master.ranks.identifier`
- `duration_days` calculated: `(to_date::date - from_date::date)` when both dates present
- `vessel_imo` truncated to 10-char varchar from bigint
- `audit_info` via `migration.build_audit_info()` extracting `CreatedById`/`UpdatedById`/`DeletedById` from SAC JSONB; fallback to `SYSTEM_USER_ID`
- Requires `seafarers`, `activity_log_types`, `activity_log_sub_types` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_activity_logs` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `activity_log_types`, `activity_log_sub_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `vessel_name_lookup` | FK lookup | `vessel_id`, `vessel_name` | - | `smac_master_migration` |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    tm.source_id::bigint as legacy_id,
    tm.target_id as new_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE target_table = 'vessels'
          AND source_id IS NOT NULL
          AND target_id IS NOT NULL
    $dblink_query$
) AS tm(source_id text, target_id uuid)
WHERE tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL
  AND tm.source_id ~ '^[0-9]+$';
```

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT DISTINCT
    r.id::bigint as legacy_id,
    r.identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
WHERE r.identifier IS NOT NULL;
```

### `vessel_name_lookup`

- **Output columns**: vessel_id, vessel_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_name_lookup AS
SELECT
    v.id as vessel_id,
    v.name as vessel_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.vessels WHERE name IS NOT NULL'
) AS v(id uuid, name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID; idempotent |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | Direct copy | Already UUID in SAC |
| 3 | `type_id` | uuid | `activity_type_id` | uuid | Direct copy | Column rename |
| 4 | `sub_type_id` | uuid | `activity_sub_type_id` | uuid | Direct copy | Column rename |
| 5 | `other_activity` | text | `other_activity` | text | `TRIM(other_activity)` | |
| 6 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` (`smac_master_migration`) | LEFT JOIN — nullable |
| 7 | via `vessel_id` | — | `vessel_name` | text | Lookup `vessel_name_lookup` on mapped `vessel_id` | From `vessel.vessels.name` |
| 8 | `vessel_imo` | bigint | `vessel_imo` | character varying(10) | `LEFT(vessel_imo::text, 10)` when not null | Cast bigint to 10-char string |
| 9 | `rank_id` | bigint | `rank_id` | uuid | Map via `ranks_id_mapping` (`synergy_master.ranks.identifier`) | LEFT JOIN — nullable |
| 10 | `from_date` | timestamp | `from_date` | timestamp without time zone | Direct copy | |
| 11 | `to_date` | timestamp | `to_date` | timestamp without time zone | Direct copy | |
| 12 | `from_date`, `to_date` | timestamp | `duration_days` | integer | `(to_date::date - from_date::date)` when both not null | Calculated field |
| 13 | `source` | text | `source` | text | `TRIM(source)` | |
| 14 | `is_manual` | boolean | `is_manual` | boolean | `COALESCE(is_manual, false)` | Defaults to false |
| 15 | — | — | `reference_entity` | text | `NULL` | No equivalent in SAC |
| 16 | — | — | `reference_id` | uuid | `NULL` | No equivalent in SAC |
| 17 | `remarks` | text | `remarks` | text | `TRIM(remarks)` | |
| 18 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 19 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 20 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 21 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 22 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | All records migrated including deleted |
| 23 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` — `CreatedById`/`UpdatedById`/`DeletedById`; fallback `SYSTEM_USER_ID` | PascalCase keys in SAC audit JSONB |

**SMAC columns not migrated:** `status`, `version`, `defined_by`, `workflow_status` — not in target schema.

**SAC columns not migrated:** None — all SAC columns in migration SELECT are mapped or absorbed into `audit_info`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `activity_log_sub_types`
- `activity_log_types`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    tm.source_id::bigint as legacy_id,
    tm.target_id as new_id
FROM dblink('smac_master_migration',
    $dblink_query$
        SELECT source_id, target_id
        FROM migration.table_mappings
        WHERE target_table = 'vessels'
          AND source_id IS NOT NULL
          AND target_id IS NOT NULL
    $dblink_query$
) AS tm(source_id text, target_id uuid)
WHERE tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL
  AND tm.source_id ~ '^[0-9]+$';
```

### 2. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT DISTINCT
    r.id::bigint as legacy_id,
    r.identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
WHERE r.identifier IS NOT NULL;
```

### 3. Vessel Name ID Mapping
**Output columns**: `vessel_id, vessel_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_name_lookup AS
SELECT
    v.id as vessel_id,
    v.name as vessel_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.vessels WHERE name IS NOT NULL'
) AS v(id uuid, name text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_activity_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_activity_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_activity_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
