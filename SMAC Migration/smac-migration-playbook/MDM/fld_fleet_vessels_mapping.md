# Table Mapping: fld_fleet_vessels → fld_fleet_vessels

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: fld_fleet_vessels
- **Source Script**: `04-migration-scripts/master/fld_fleet_vessels_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fld_fleet_vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_details_mapping` | -------------------------------- | `vd.identifier`, `vd.vessel_id` | - | `synergy_vessel` |

### `vessel_details_mapping`

- **Purpose**: --------------------------------
- **Output columns**: vd.identifier, vd.vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.identifier,
    vd.vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL
       AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel', 'public', 'fleet_vessel_mapping', mws.legacy_id::text, current_database()::varchar, 'vessel', 'fld_fleet_vessels', mws.legacy_id, ... |
| 2 | new_fleet_id | - | fleet_id | - | mws.new_fleet_id | mws.new_fleet_id |
| 3 | new_vessel_id | - | vessel_id | - | mws.new_vessel_id | mws.new_vessel_id |
| 4 | legacy_vessel_id | - | vessel_revision_id | - | mws.legacy_vessel_id AS vessel_revision_id | mws.legacy_vessel_id |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL | NULL |
| 7 | derived | - | version | - | 1 | 1 |
| 8 | derived | - | level | - | NULL | NULL |
| 9 | derived | - | tags | - | NULL | NULL |
| 10 | deleted_at, legacy_status | - | status | - | CASE WHEN mws.deleted_at IS NOT NULL THEN 3 WHEN mws.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(mws.legacy_status)) = 'ACTIVE' OR TRIM(mws.legacy_status) = '0' THEN 0 WHEN UPP... | CASE WHEN mws.deleted_at IS NOT NULL THEN 3 WHEN mws.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(mws.legacy_status)) = 'ACTIVE' OR TRIM(mws.legacy_status) = '0' THEN 0 WHEN UPP... |
| 11 | derived | - | workflow_status | - | 2 | 2 |
| 12 | derived | - | defined_by | - | 0 | 0 |
| 13 | created_at | - | created_at | - | COALESCE(mws.created_at, NOW()) | COALESCE(mws.created_at, NOW()) |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(mws.updated_at, mws.created_at, NOW()) | COALESCE(mws.updated_at, mws.created_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | mws.deleted_at | mws.deleted_at |
| 16 | derived | - | archived_at | - | NULL | NULL |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID', NULL, :'SYSTEM_USER_ID', NULL, NULL, NULL, NULL, NULL, NULL, NULL ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Details ID Mapping
**Purpose**: --------------------------------
**Output columns**: `vd.identifier, vd.vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.identifier,
    vd.vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL
       AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

Full migration context: `04-migration-scripts/master/fld_fleet_vessels_migration.sql`

## Validation

- Run `05-validation/master/fld_fleet_vessels_validation.sql` if available
- Run `06-rollback/master/fld_fleet_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
