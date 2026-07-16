# Table Mapping: vessel_charterer_details → vessel_charterers

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_charterer_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_charterers
- **Source Script**: `04-migration-scripts/master/vessel_charterers_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_charterer_details`
- **New Path**: `smac_master_migration.vessel.vessel_charterers`

## Business Key

- **Composite Key**: (`vessel_id`, `charterer_id`)
- **Source (orchestration)**: Vessel Charterer Details (`vessel_charterer_details` → `vessel_charterers`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_charterer_details preserving identifier UUID as id if available. Maps vessel_id through vessel_details â†’ migration.table_mappings. Maps charterer_type â†’ charterer_types.name â†’ charterer_types.id

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_charterers` before insert (full table reload).
- Orchestration dependencies: `vessels`, `charterer_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `charterer_id_mapping` | FK lookup | `charterer_name`, `charterer_id` | - | - |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_charterer_details)'
) AS vd(id bigint, vessel_id bigint)
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### `charterer_id_mapping`

- **Output columns**: charterer_name, charterer_id

```sql
CREATE TEMP TABLE charterer_id_mapping AS
SELECT
    c.name as charterer_name,
    c.id as charterer_id
FROM vessel.charterers c;
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
| 1 | identifier, vessel_id, name | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_charterer_details'::VARCHAR(100), COALESCE(legacy_data.identifier::text, LEFT((legac... |
| 2 | derived | - | vessel_id | - | vim.new_vessel_id as vessel_id | vim.new_vessel_id |
| 3 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | charterer_id | - | cim.charterer_id | cim.charterer_id |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 9 | derived | - | status | - | 0 as status | 0 |
| 10 | created_at | - | created_at | - | CASE WHEN legacy_data.created_at IS NULL THEN NOW() WHEN legacy_data.created_at = 'infinity'::timestamp OR legacy_data.created_at = '-infinity'::timestamp OR legacy_data.created... | CASE WHEN legacy_data.created_at IS NULL THEN NOW() WHEN legacy_data.created_at = 'infinity'::timestamp OR legacy_data.created_at = '-infinity'::timestamp OR legacy_data.created... |
| 11 | updated_at, created_at | - | updated_at | - | CASE WHEN legacy_data.updated_at IS NULL OR legacy_data.updated_at = 'infinity'::timestamp OR legacy_data.updated_at = '-infinity'::timestamp OR legacy_data.updated_at > '9999-1... | CASE WHEN legacy_data.updated_at IS NULL OR legacy_data.updated_at = 'infinity'::timestamp OR legacy_data.updated_at = '-infinity'::timestamp OR legacy_data.updated_at > '9999-1... |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `charterers`
- `vessel_revisions`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_charterer_details)'
) AS vd(id bigint, vessel_id bigint)
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Charterer ID Mapping
**Output columns**: `charterer_name, charterer_id`

```sql
CREATE TEMP TABLE charterer_id_mapping AS
SELECT
    c.name as charterer_name,
    c.id as charterer_id
FROM vessel.charterers c;
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

Full migration context: `04-migration-scripts/master/vessel_charterers_migration.sql`

## Validation

- Run `05-validation/master/vessel_charterers_validation.sql` if available
- Run `06-rollback/master/vessel_charterers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
