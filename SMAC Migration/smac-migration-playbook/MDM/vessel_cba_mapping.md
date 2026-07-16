# Table Mapping: vessel_cba_mapping → vessel_cba_mapping

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_cba_mapping
- **Source Script**: `04-migration-scripts/master/vessel_cba_mapping_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details.cba_code (text[] array)`
- **New Path**: `smac_master_migration.vessel.vessel_cba_mapping`

## Business Key

- **Composite Key**: (`vessel_id`, `cba_id`)
- **Source (orchestration)**: Vessel CBA Mapping (`vessel_details` → `vessel_cba_mapping`)

## Migration Notes

- Parses text[] array cba_code values from vessel_details table
- Creates junction records linking vessel_id to cba_id
- Maps vessel_id (bigint) via migration.table_mappings (vessels)
- Maps cba_id by matching cba_code with cbas.code, then via migration.table_mappings (cbas)
- Maps vessel_revision_id from active vessel_revisions via lookup table
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- NOTE: vessel_cba_mapping depends on vessels, vessel_revisions, and cbas
- Parses text[] array cba_code values from vessel_details table, creates junction records

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
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details'::VARCHAR(100), LEFT((md.legacy_vessel_id::text || '_' || COALESCE(md.legacy... |
| 2 | derived | - | vessel_id | - | md.vessel_id | md.vessel_id |
| 3 | derived | - | cba_id | - | md.cba_id | md.cba_id |
| 4 | derived | - | vessel_revision_id | - | COALESCE(md.vessel_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_revision_id | COALESCE(md.vessel_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | derived | - | level | - | 0 as level | 0 |
| 9 | derived | - | tags | - | NULL as tags | NULL |
| 10 | - | - | status | - | DEFAULT_STATUS | :'DEFAULT_STATUS'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 13 | derived | - | created_at | - | COALESCE(md.created_at, NOW()) as created_at | COALESCE(md.created_at, NOW()) |
| 14 | derived | - | updated_at | - | COALESCE(md.updated_at, NOW()) as updated_at | COALESCE(md.updated_at, NOW()) |
| 15 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 16 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cbas`
- `vessel.vessel_revisions`
- `vessel.vessels`

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
