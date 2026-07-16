# Table Mapping: vessel_particulars → vessel_particulars

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: vessel_particulars
- **Source Script**: `04-migration-scripts/master/vessel_particulars_migration.sql`


## Business Key

- **Business Key**: `vessel_id`
- **Source (orchestration)**: Vessel Particulars (`vessel_particulars` → `vessel_particulars`)

## Migration Notes

- Uses migration.resolve_target_id() for idempotent UUID generation (source table has identifier/uuid column)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessels table to be migrated first (vessel_id foreign key)
- Migrates designed_draught, light_displacement, and bulbous_bow from vessel_particulars
- Migrates dual_fuelship, hull_number, electronic_engine, polar_code_applicable from vessel_details
- Migrates vessel_particulars preserving identifier/uuid UUID as id. Requires vessels table to be migrated first.

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Rule 2.5: Use simple pattern without UUID - use legacy_id (bigint) instead
- Script performs `TRUNCATE TABLE vessel.vessel_particulars` before insert (full table reload).
- Orchestration dependencies: `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_details_lookup` | FK lookup | `legacy_vessel_id`, `vd.dual_fuelship`, `vd.hull_number`, `vd.electronic_engine`, `vd.polar_code_applicable`, `vd.ice_class` | - | `synergy_vessel` |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT ON (vd.id)
    vd.id AS legacy_id,
    v_mapping.target_id AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings v_mapping
    ON v_mapping.source_id = vd.vessel_id::text
    AND v_mapping.target_table = 'vessels'
    AND v_mapping.target_db = current_database()
ORDER BY
    vd.id,
    (v_mapping.target_id IS NOT NULL) DESC,
    v_mapping.migrated_at DESC NULLS LAST;
```

### `vessel_details_lookup`

- **Output columns**: legacy_vessel_id, vd.dual_fuelship, vd.hull_number, vd.electronic_engine, vd.polar_code_applicable, vd.ice_class
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.dual_fuelship,
    vd.hull_number,
    vd.electronic_engine,
    vd.polar_code_applicable,
    vd.ice_class
FROM dblink('synergy_vessel',
    'SELECT vessel_id, dual_fuelship, hull_number, electronic_engine, polar_code_applicable, ice_class, status, updated_at
     FROM public.vessel_details
     WHERE vessel_id IS NOT NULL
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    dual_fuelship boolean,
    hull_number text,
    electronic_engine boolean,
    polar_code_applicable boolean,
    ice_class boolean,
    status text,
    updated_at timestamp
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id, legacy_identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_particulars'::VARCHAR(100), s.legacy_id, current_database()::text::VARCHAR(100), 've... |
| 2 | legacy_id | - | code | - | LEFT('VESSEL_PARTICULARS_' || s.legacy_id, 50) AS code | LEFT('VESSEL_PARTICULARS_' || s.legacy_id, 50) |
| 3 | legacy_id | - | name | - | LEFT('Vessel Particulars ' || s.legacy_id, 255) AS name | LEFT('Vessel Particulars ' || s.legacy_id, 255) |
| 4 | derived | - | vessel_id | - | COALESCE(vm.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_id | COALESCE(vm.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | gross_ton | - | gross_ton | - | s.gross_ton | s.gross_ton |
| 6 | net_ton | - | net_ton | - | s.net_ton | s.net_ton |
| 7 | dead_weight | - | dead_weight | - | s.dead_weight | s.dead_weight |
| 8 | bhp | - | bhp | - | s.bhp | s.bhp |
| 9 | loa_length | - | length_loa | - | s.loa_length AS length_loa | s.loa_length |
| 10 | lbp_length | - | length_lbp | - | s.lbp_length AS length_lbp | s.lbp_length |
| 11 | breadth | - | breadth | - | s.breadth | s.breadth |
| 12 | depth | - | depth | - | s.depth | s.depth |
| 13 | tonnage_per_cm | - | tonnage_per_cm | - | s.tonnage_per_cm | s.tonnage_per_cm |
| 14 | displacement | - | displacement_tonnage | - | s.displacement AS displacement_tonnage | s.displacement |
| 15 | designed_draught | - | designed_draught | - | s.designed_draught | s.designed_draught |
| 16 | light_displacement | - | light_displacement | - | s.light_displacement | s.light_displacement |
| 17 | bulbous_bow | - | bulbous_bow | - | s.bulbous_bow | s.bulbous_bow |
| 18 | derived | - | dual_fuelship | - | vdl.dual_fuelship | vdl.dual_fuelship |
| 19 | derived | - | hull_number | - | vdl.hull_number | vdl.hull_number |
| 20 | derived | - | electronic_engine | - | vdl.electronic_engine | vdl.electronic_engine |
| 21 | derived | - | polar_code_applicable | - | vdl.polar_code_applicable | vdl.polar_code_applicable |
| 22 | derived | - | ice_class | - | vdl.ice_class | vdl.ice_class |
| 23 | keel_to_masthead | - | keel_to_masthead | - | s.keel_to_masthead | s.keel_to_masthead |
| 24 | keel_to_mastheight | - | height_above_keel | - | s.keel_to_mastheight AS height_above_keel | s.keel_to_mastheight |
| 25 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 26 | derived | - | version | - | 1 AS version | 1 |
| 27 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 28 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 29 | derived | - | status | - | 0 AS status | 0 |
| 30 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 31 | legacy_updated_at | - | updated_at | - | COALESCE(s.legacy_updated_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, NOW()) |
| 32 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( s.created_by_id::varchar, NULL::varchar, s.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::va... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT ON (vd.id)
    vd.id AS legacy_id,
    v_mapping.target_id AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
LEFT JOIN migration.table_mappings v_mapping
    ON v_mapping.source_id = vd.vessel_id::text
    AND v_mapping.target_table = 'vessels'
    AND v_mapping.target_db = current_database()
ORDER BY
    vd.id,
    (v_mapping.target_id IS NOT NULL) DESC,
    v_mapping.migrated_at DESC NULLS LAST;
```

### 2. Vessel Details ID Mapping
**Output columns**: `legacy_vessel_id, vd.dual_fuelship, vd.hull_number, vd.electronic_engine, vd.polar_code_applicable, vd.ice_class`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_lookup AS
SELECT DISTINCT ON (vd.vessel_id)
    vd.vessel_id AS legacy_vessel_id,
    vd.dual_fuelship,
    vd.hull_number,
    vd.electronic_engine,
    vd.polar_code_applicable,
    vd.ice_class
FROM dblink('synergy_vessel',
    'SELECT vessel_id, dual_fuelship, hull_number, electronic_engine, polar_code_applicable, ice_class, status, updated_at
     FROM public.vessel_details
     WHERE vessel_id IS NOT NULL
     ORDER BY vessel_id,
              CASE WHEN UPPER(TRIM(status)) = ''ACTIVE'' THEN 0 ELSE 1 END,
              updated_at DESC NULLS LAST'
) AS vd(
    vessel_id bigint,
    dual_fuelship boolean,
    hull_number text,
    electronic_engine boolean,
    polar_code_applicable boolean,
    ice_class boolean,
    status text,
    updated_at timestamp
);
```

Full migration context: `04-migration-scripts/master/vessel_particulars_migration.sql`

## Validation

- Run `05-validation/master/vessel_particulars_validation.sql` if available
- Run `06-rollback/master/vessel_particulars_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
