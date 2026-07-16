# Table Mapping: vessel_engine_info → vessel_engines

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_engine_info
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_engines
- **Source Script**: `04-migration-scripts/master/vessel_engines_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_engine_info`
- **New Path**: `smac_master_migration.vessel.vessel_engines`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Vessel Engines (`vessel_engine_info` → `vessel_engines`)

## Migration Notes

- SAC `id` (bigint) → SMAC `id` via `migration.resolve_target_id()` with `p_target_id = NULL`
- Filter in dblink: `vessel_id IS NOT NULL`; INSERT requires valid vessel mapping
- `engine_model_id`, `engine_make_id` used directly as UUIDs from source
- `engine_type` mapped: SAC 1→SMAC 0 (Main), 2→1 (Auxiliary)
- `display_name` generated as `'Engine ' || legacy_id`
- `status` Case 2: `deleted_at` takes precedence over `status` string
- `ncr_kw`, `ncr_rpm` set to NULL — not in SAC source
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_engines` before insert (full table reload).
- Orchestration dependencies: `vessels`, `engine_models`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `vessel_id_target` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, vessel_id_target
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vessel_id
     FROM public.vessel_engine_info
     WHERE vessel_id IS NOT NULL'
) AS vme(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vme.vessel_id
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` or placeholder UUID | FK lookup; required |
| 3 | `engine_model_id` | uuid | `engine_model_id` | uuid | Direct copy | UUID preserved from SAC |
| 4 | `engine_make_id` | uuid | `engine_make_id` | uuid | Direct copy | UUID preserved from SAC |
| 5 | `id` | bigint | `display_name` | text | `'Engine ' || id::text` | Generated display name |
| 6 | `engine_type_id` | integer | `engine_type` | integer | SAC `1` → Main (0); SAC `2` → Auxiliary (1) | Enum remapping |
| 7 | `mcr_kw` | numeric | `mcr_kw` | numeric | Direct cast | Direct copy |
| 8 | `mcr_bhp` | numeric | `mcr_bhp` | numeric | Direct cast | Direct copy |
| 9 | `mcr_rpm` | numeric | `mcr_rpm` | numeric | Direct cast | Direct copy |
| 10 | `—` | — | `ncr_kw` | numeric | `NULL` | Not in SAC source |
| 11 | `—` | — | `ncr_rpm` | numeric | `NULL` | Not in SAC source |
| 12 | `electronic_engine ` | boolean | `electronic_engine` | boolean | Direct copy | Note trailing space in SAC column name |
| 13 | `—` | — | `vessel_revision_id` | uuid | Active revision or placeholder UUID | FK lookup |
| 14 | `electronic_engine` | boolean | `electronic_engine` | boolean | Direct copy | From SAC source |
| 15 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 16 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 17 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 18 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 19 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |
| 20 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not sourced from SAC |
| 21 | `status, deleted_at` | text, timestamp | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 22 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 23 | `updated_at, created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Fallback chain |
| 24 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 25 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 26 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | Source `audit_info` replaced |
| 27 | `—` | — | `level` | numeric | Hardcoded NULL | Not in SAC source |

**SAC columns not migrated:** `mcr_hp`, `me_sump` — noted in script header, not in dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `engine_models`
- `vessel.engine_models`
- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, vessel_id_target`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_vessel',
    'SELECT DISTINCT vessel_id
     FROM public.vessel_engine_info
     WHERE vessel_id IS NOT NULL'
) AS vme(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = vme.vessel_id
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/master/vessel_engines_migration.sql`

## Validation

- Run `05-validation/master/vessel_engines_validation.sql` if available
- Run `06-rollback/master/vessel_engines_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
