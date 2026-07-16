# Table Mapping: vessel_minimum_safe_mannings → vessel_minimum_safe_mannings

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: vessel_minimum_safe_mannings
- **Source Script**: `04-migration-scripts/master/vessel_minimum_safe_mannings_migration.sql`


## Business Key

- **Business Key**: `vessel_id`
- **Source (orchestration)**: Vessels Minimum Safe Manning (`vessels_minimum_safe_manning` → `vessel_minimum_safe_mannings`)

## Migration Notes

- Uses migration.resolve_target_id() for idempotent UUID generation (source table has identifier/uuid column)
- Maps rank column names to msm_positions.id via public.msm_positions table
- Inserts numeric value from rank columns as value field
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessels, vessel_revisions, and msm_positions tables to be migrated first
- Migrates vessels_minimum_safe_manning preserving identifier/uuid UUID as id. Requires vessels table to be migrated first.

## Special Considerations

- Uses composite source_id (legacy_id || '|rank_column') for unpivoted rows to ensure unique, idempotent IDs
- Unpivots rank columns (master, chief_engineer, etc.) into individual rows
- Run schema discovery first to verify identifier/uuid columns exist and rank column names
- Script performs `TRUNCATE TABLE vessel.vessel_minimum_safe_mannings` before insert (full table reload).
- Orchestration dependencies: `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_details_to_vessels_mapping` | FK lookup | `legacy_vessel_details_id`, `legacy_vessel_id` | - | `synergy_vessel` |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `final_vessel_id_mapping` | Clea | `vdtvm.legacy_vessel_details_id`, `smac_vessel_id` | - | - |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |
| `msm_position_lookup` | Store in session | `msm_position_id`, `position_name_lower`, `position_code_lower`, `position_name`, `position_code` | - | - |

### `vessel_details_to_vessels_mapping`

- **Output columns**: legacy_vessel_details_id, legacy_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessels_mapping AS
SELECT DISTINCT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessels_minimum_safe_manning WHERE vessel_id IS NOT NULL)'
) AS vd(
    id bigint,
    vessel_id bigint
);
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `final_vessel_id_mapping`

- **Purpose**: Clea
- **Output columns**: vdtvm.legacy_vessel_details_id, smac_vessel_id

```sql
CREATE TEMP TABLE final_vessel_id_mapping AS
SELECT
    vdtvm.legacy_vessel_details_id,
    vm.new_id AS smac_vessel_id
FROM vessel_details_to_vessels_mapping vdtvm
LEFT JOIN vessels_id_mapping vm ON vm.legacy_id = vdtvm.legacy_vessel_id;
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

### `msm_position_lookup`

- **Purpose**: Store in session
- **Output columns**: msm_position_id, position_name_lower, position_code_lower, position_name, position_code

```sql
CREATE TEMP TABLE msm_position_lookup AS
SELECT
    mp.id AS msm_position_id,
    LOWER(TRIM(mp.name)) AS position_name_lower,
    LOWER(TRIM(mp.code)) AS position_code_lower,
    mp.name AS position_name,
    mp.code AS position_code
FROM public.msm_positions mp
WHERE mp.name IS NOT NULL AND TRIM(mp.name) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessels_minimum_safe_manning'::VARCHAR(100), s.legacy_id || '|master', current_database()::... |
| 2 | derived | - | vessel_id | - | COALESCE(fvm.smac_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_id | COALESCE(fvm.smac_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | msm_position_id | - | mpl.msm_position_id | mpl.msm_position_id |
| 5 | master_value | - | value | - | s.master_value AS value | s.master_value |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 9 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 10 | legacy_deleted_at | - | status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 12 | legacy_updated_at | - | updated_at | - | COALESCE(s.legacy_updated_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, NOW()) |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.msm_positions`
- `vessel.vessel_revisions`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Details To Vessels ID Mapping
**Output columns**: `legacy_vessel_details_id, legacy_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessels_mapping AS
SELECT DISTINCT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessels_minimum_safe_manning WHERE vessel_id IS NOT NULL)'
) AS vd(
    id bigint,
    vessel_id bigint
);
```

### 2. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 3. Final Vessel ID Mapping
**Purpose**: Clea
**Output columns**: `vdtvm.legacy_vessel_details_id, smac_vessel_id`

```sql
CREATE TEMP TABLE final_vessel_id_mapping AS
SELECT
    vdtvm.legacy_vessel_details_id,
    vm.new_id AS smac_vessel_id
FROM vessel_details_to_vessels_mapping vdtvm
LEFT JOIN vessels_id_mapping vm ON vm.legacy_id = vdtvm.legacy_vessel_id;
```

### 4. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 5. Msm Position ID Mapping
**Purpose**: Store in session
**Output columns**: `msm_position_id, position_name_lower, position_code_lower, position_name, position_code`

```sql
CREATE TEMP TABLE msm_position_lookup AS
SELECT
    mp.id AS msm_position_id,
    LOWER(TRIM(mp.name)) AS position_name_lower,
    LOWER(TRIM(mp.code)) AS position_code_lower,
    mp.name AS position_name,
    mp.code AS position_code
FROM public.msm_positions mp
WHERE mp.name IS NOT NULL AND TRIM(mp.name) <> '';
```

Full migration context: `04-migration-scripts/master/vessel_minimum_safe_mannings_migration.sql`

## Validation

- Run `05-validation/master/vessel_minimum_safe_mannings_validation.sql` if available
- Run `06-rollback/master/vessel_minimum_safe_mannings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
