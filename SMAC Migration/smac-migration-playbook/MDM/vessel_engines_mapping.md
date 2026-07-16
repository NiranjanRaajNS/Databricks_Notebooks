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

- Uses migration.resolve_target_id() for idempotent UUID generation (source table has no identifier/uuid column)
- Map vessel_id (bigint) → vessel_id (uuid) via migration.table_mappings
- engine_model_id is already UUID in source (references engine_model.identifier) - use directly
- engine_make_id is already UUID in source (references engine_make.identifier) - use directly
- Generate display_name (NOT NULL in target, source has no engine_name column)
- Convert mcr__kw, mcr__bhp, mcr_rpm from integer to numeric
- mcr__hp and me_sump are not in target table (skip)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessels and vessel.engine_models to be migrated first
- Migrates vessel_engine_info to vessel_engines. Generates new UUIDs for id (source has no identifier/uuid). Maps vessel_id (bigint) → vessel_details.id → vessel_details.vessel_id → migration.table_mappings (vessels) → vessel_id (uuid). Uses engine_model_id (uuid) and engine_make_id (uuid) directly from source (already UUIDs, reference engine_model.identifier and engine_make.identifier). Generates display_name as 'Engine ' || legacy_id (NOT NULL constraint, source has no engine_name column). Converts mcr_kw, mcr_bhp, mcr_rpm from double precision to numeric. Includes electronic_engine boolean from source. Requires vessels and engine_models to be migrated first.

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
| 1 | legacy_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_engine_info'::VARCHAR(100), s.legacy_id, current_database()::text::VARCHAR(100), 've... |
| 2 | derived | - | vessel_id | - | COALESCE(vim.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_id | COALESCE(vim.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | engine_model_id | - | engine_model_id | - | s.engine_model_id AS engine_model_id | s.engine_model_id |
| 4 | engine_make_id | - | engine_make_id | - | s.engine_make_id AS engine_make_id | s.engine_make_id |
| 5 | legacy_id | - | display_name | - | 'Engine ' || s.legacy_id AS display_name | 'Engine ' || s.legacy_id |
| 6 | legacy_engine_type_id | - | engine_type | - | CASE WHEN s.legacy_engine_type_id = 1 THEN 0 WHEN s.legacy_engine_type_id = 2 THEN 1 ELSE NULL END AS engine_type | CASE WHEN s.legacy_engine_type_id = 1 THEN 0 WHEN s.legacy_engine_type_id = 2 THEN 1 ELSE NULL END |
| 7 | mcr_kw | - | mcr_kw | - | CASE WHEN s.mcr_kw IS NOT NULL THEN s.mcr_kw::numeric ELSE NULL END AS mcr_kw | CASE WHEN s.mcr_kw IS NOT NULL THEN s.mcr_kw::numeric ELSE NULL END |
| 8 | mcr_bhp | - | mcr_bhp | - | CASE WHEN s.mcr_bhp IS NOT NULL THEN s.mcr_bhp::numeric ELSE NULL END AS mcr_bhp | CASE WHEN s.mcr_bhp IS NOT NULL THEN s.mcr_bhp::numeric ELSE NULL END |
| 9 | mcr_rpm | - | mcr_rpm | - | CASE WHEN s.mcr_rpm IS NOT NULL THEN s.mcr_rpm::numeric ELSE NULL END AS mcr_rpm | CASE WHEN s.mcr_rpm IS NOT NULL THEN s.mcr_rpm::numeric ELSE NULL END |
| 10 | derived | - | ncr_kw | - | NULL AS ncr_kw | NULL |
| 11 | derived | - | ncr_rpm | - | NULL AS ncr_rpm | NULL |
| 12 | electronic_engine | - | electronic_engine | - | s.electronic_engine AS electronic_engine | s.electronic_engine |
| 13 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 14 | derived | - | tags | - | NULL AS tags | NULL |
| 15 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 16 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 17 | derived | - | version | - | 1 AS version | 1 |
| 18 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 19 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 20 | deleted_at, legacy_status | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'DRAFT' THEN 1 WHEN... | CASE WHEN s.deleted_at IS NOT NULL THEN 3 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'DRAFT' THEN 1 WHEN... |
| 21 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 22 | updated_at, created_at | - | updated_at | - | COALESCE(s.updated_at, s.created_at, NOW()) AS updated_at | COALESCE(s.updated_at, s.created_at, NOW()) |
| 23 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 24 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 25 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 26 | derived | - | level | - | NULL AS level | NULL |

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
