# Table Mapping: vessel_particulars → vessel_particulars

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_particulars
- **Source Script**: `04-migration-scripts/master/vessel_particulars_migration.sql`

- **New Path**: `smac_master_migration.vessel.vessel_particulars`

## Business Key

- **Business Key**: `vessel_id`
- **Source (orchestration)**: Vessel Particulars (`vessel_particulars` → `vessel_particulars`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- `vessel_id` via `vessel_details` → vessels mapping (placeholder when unmapped)
- `code`/`name` generated from legacy `id` — SAC has no code/name columns
- Capacity columns migrated separately to `vessel.vessel_capacity`
- `dual_fuelship`, `hull_number`, etc. from `vessel_details` lookup (latest active revision)
- `status` hardcoded Active (0)
- `DISTINCT ON (COALESCE(identifier::text, id::text))`
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
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC uuid as SMAC id |
| 2 | `id` | bigint | `code` | text | `'VESSEL_PARTICULARS_' || id::text` | Generated code |
| 3 | `id` | bigint | `name` | text | `'Vessel Particulars ' || id::text` | Generated name |
| 4 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` or placeholder UUID | FK lookup |
| 5 | `gross_ton` | numeric | `gross_ton` | numeric | Direct copy | Direct copy |
| 6 | `net_ton` | numeric | `net_ton` | numeric | Direct copy | Direct copy |
| 7 | `dead_weight` | numeric | `dead_weight` | numeric | Direct copy | Direct copy |
| 8 | `bhp` | numeric | `bhp` | numeric | Direct copy | Direct copy |
| 9 | `loa_length` | numeric | `length_loa` | numeric | Direct copy | Column rename |
| 10 | `lbp_length` | numeric | `length_lbp` | numeric | Direct copy | Column rename |
| 11 | `breadth` | numeric | `breadth` | numeric | Direct copy | Direct copy |
| 12 | `depth` | numeric | `depth` | numeric | Direct copy | Direct copy |
| 13 | `tonnage_per_cm` | numeric | `tonnage_per_cm` | numeric | Direct copy | Direct copy |
| 14 | `displacement` | numeric | `displacement_tonnage` | numeric | Direct copy | Column rename |
| 15 | `designed_draught` | numeric | `designed_draught` | numeric | Direct copy | Direct copy |
| 16 | `light_displacement` | numeric | `light_displacement` | numeric | Direct copy | Direct copy |
| 17 | `bulbous_bow` | boolean | `bulbous_bow` | boolean | Direct copy | Direct copy |
| 18 | `dual_fuelship` | boolean | `dual_fuelship` | boolean | From `vessel_details` lookup join | Latest active revision data |
| 19 | `hull_number` | character varying | `hull_number` | text | From `vessel_details` lookup join | Latest active revision data |
| 20 | `electronic_engine` | boolean | `electronic_engine` | boolean | From `vessel_details` lookup join | Latest active revision data |
| 21 | `polar_code_applicable` | boolean | `polar_code_applicable` | boolean | From `vessel_details` lookup join | Latest active revision data |
| 22 | `ice_class` | boolean | `ice_class` | boolean | From `vessel_details` lookup join | Latest active revision data |
| 23 | `keel_to_masthead` | numeric | `keel_to_masthead` | numeric | Direct copy | Direct copy |
| 24 | `keel_to_mastheight` | numeric | `height_above_keel` | numeric | Direct copy | Column rename |
| 25 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 26 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 27 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |
| 28 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not sourced from SAC |
| 29 | `—` | — | `status` | integer | Hardcoded `0` (Active) | SAC `status` not migrated |
| 30 | `created_by_id, updated_by_id, created_by_name, updated_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` with user IDs and name notes | Pattern 4; no `legacy_id` |
| 31 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 32 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |

**SAC columns not migrated:** Capacity columns (`capacity`, `teu_capacity`, `grain_capacity`, etc.) — migrated separately in `vessel_capacity` migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessels`

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
