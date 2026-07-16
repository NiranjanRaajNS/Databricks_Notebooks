# Table Mapping: vessel_cba_mapping → vessel_cba_mapping

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details (`cba_code` column)
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_cba_mapping
- **Source Script**: `04-migration-scripts/master/vessel_cba_mapping_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details.cba_code` (text[] array)
- **New Path**: `smac_master_migration.vessel.vessel_cba_mapping`

## Business Key

- **Composite Key**: (`vessel_id`, `cba_id`)
- **Source (orchestration)**: Vessel CBA Mapping (`vessel_details` → `vessel_cba_mapping`)

## Migration Notes

- Unnests SAC `vessel_details.cba_code` text[] array — one junction row per (vessel, cba_code) pair
- `id` via `migration.resolve_target_id()` with composite source_id `legacy_vessel_id_legacy_cba_id`; idempotent via `id_mappings`
- `vessel_id` mapped via `vessel_id_mapping` (`vessel_details.vessel_id` → `migration.table_mappings` for `vessels`)
- `cba_id` resolved by matching `UPPER(TRIM(cba_code))` to `cbas.code`, then `migration.table_mappings` for `cbas`
- `vessel_revision_id` from latest `vessel_revisions` per vessel; fallback to zero UUID
- `status`, `workflow_status`, `defined_by` from `constants.sql` defaults
- Requires `vessels`, `vessel_revisions`, and `cbas` migrated first
- Filter: only rows where `cba_code` array is non-empty and code element is non-blank

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_cba_mapping` before insert (full table reload).
- Orchestration dependencies: `vessels`, `cbas`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `legacy_vessel_id`, `smac_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `cba_code_lookup` | FK lookup | `c.code`, `legacy_cba_id`, `cba_id` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, legacy_vessel_id, smac_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    vd.id as vessel_details_id,
    vd.vessel_id as legacy_vessel_id,
    tm.target_id as smac_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE cba_code IS NOT NULL AND array_length(cba_code, 1) > 0'
) AS vd(id bigint, vessel_id bigint)
INNER JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### `cba_code_lookup`

- **Output columns**: c.code, legacy_cba_id, cba_id
- **migration.table_mappings**: target_table=cbas
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE cba_code_lookup AS
SELECT
    c.code,
    c.id as legacy_cba_id,
    tm.target_id as cba_id
FROM dblink('synergy_master',
    'SELECT id, code FROM public.cbas WHERE code IS NOT NULL AND LENGTH(TRIM(code)) > 0'
) AS c(id bigint, code text)
INNER JOIN migration.table_mappings tm
    ON tm.target_table = 'cbas'
    AND tm.target_db = current_database()
    AND tm.source_id = c.id::text;
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `vessel_id`, `cba_code` | bigint, text[] | `id` | uuid | `migration.resolve_target_id()` — source_id = `legacy_vessel_id::text \|\| '_' \|\| legacy_cba_id` | Composite key per vessel-CBA pair; idempotent via `id_mappings` |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` (`vessel_details.vessel_id` → `vessels` UUID) | Lookup: `migration.table_mappings` where `target_table = 'vessels'` |
| 3 | `cba_code` | text[] | `cba_id` | uuid | Unnest array; match `UPPER(TRIM(code))` to `cbas.code` → `cba_code_lookup` | Lookup: `migration.table_mappings` where `target_table = 'cbas'` |
| 4 | — | — | `vessel_revision_id` | uuid | Latest `vessel_revisions` per vessel via `vessel_revision_id_mapping`; fallback zero UUID | Active revision = most recent by `created_at` |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 9 | — | — | `tags` | text[] | `NULL` | Not populated from SAC source |
| 10 | — | — | `status` | integer | `:'DEFAULT_STATUS'::integer` from `constants.sql` | Default: Active (0); not in SAC source |
| 11 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 12 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 15 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC soft-delete not migrated to junction rows |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | SAC `audit_info` not directly mapped; composite source_id in `id_mappings` |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** Other `vessel_details` attributes — only `vessel_id`, `cba_code`, and audit timestamps used.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `cbas`
- `crewing.cbas`
- `vessel.vessel_revisions`
- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, legacy_vessel_id, smac_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    vd.id as vessel_details_id,
    vd.vessel_id as legacy_vessel_id,
    tm.target_id as smac_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE cba_code IS NOT NULL AND array_length(cba_code, 1) > 0'
) AS vd(id bigint, vessel_id bigint)
INNER JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Cba Code ID Mapping
**Output columns**: `c.code, legacy_cba_id, cba_id`
**migration.table_mappings**: `target_table='cbas'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE cba_code_lookup AS
SELECT
    c.code,
    c.id as legacy_cba_id,
    tm.target_id as cba_id
FROM dblink('synergy_master',
    'SELECT id, code FROM public.cbas WHERE code IS NOT NULL AND LENGTH(TRIM(code)) > 0'
) AS c(id bigint, code text)
INNER JOIN migration.table_mappings tm
    ON tm.target_table = 'cbas'
    AND tm.target_db = current_database()
    AND tm.source_id = c.id::text;
```

### 3. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/master/vessel_cba_mapping_migration.sql`

## Validation

- Run `05-validation/master/vessel_cba_mapping_validation.sql` if available
- Run `06-rollback/master/vessel_cba_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
