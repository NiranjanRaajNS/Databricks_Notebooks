# Table Mapping: addonvessels → add_on_vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: addonvessels
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: add_on_vessels
- **Source Script**: `04-migration-scripts/master/add_on_vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.addonvessels`
- **New Path**: `smac_master_migration.vessel.add_on_vessels`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessels (`vessels` → `vessels`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.add_on_vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'addonvessels'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), ... |
| 2 | ship_name, id | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.ship_name), legacy_data.id::text) |
| 3 | ship_name | - | name | - | TRIM(legacy_data.ship_name) as name | TRIM(legacy_data.ship_name) |
| 4 | vessel_id | - | vessel_id | - | legacy_data.vessel_id::text as vessel_id | legacy_data.vessel_id::text |
| 5 | ship_name | - | ship_name | - | TRIM(legacy_data.ship_name) as ship_name | TRIM(legacy_data.ship_name) |
| 6 | imo_no | - | imo_no | - | legacy_data.imo_no::text as imo_no | legacy_data.imo_no::text |
| 7 | shiptype | - | shiptype | - | NULLIF(TRIM(legacy_data.shiptype), '') as shiptype | NULLIF(TRIM(legacy_data.shiptype), '') |
| 8 | shiptype_synergy | - | shiptype_synergy | - | legacy_data.shiptype_synergy::text as shiptype_synergy | legacy_data.shiptype_synergy::text |
| 9 | flag | - | flag | - | legacy_data.flag::text as flag | legacy_data.flag::text |
| 10 | port_of_registry | - | port_of_registry | - | legacy_data.port_of_registry::text as port_of_registry | legacy_data.port_of_registry::text |
| 11 | gross | - | gross | - | legacy_data.gross::text as gross | legacy_data.gross::text |
| 12 | net_tonnage_nt | - | net_tonnage_nt | - | legacy_data.net_tonnage_nt::text as net_tonnage_nt | legacy_data.net_tonnage_nt::text |
| 13 | deadweight | - | deadweight | - | legacy_data.deadweight::text as deadweight | legacy_data.deadweight::text |
| 14 | light_displacement_tonnage_ldt | - | light_displacement_tonnage_ldt | - | legacy_data.light_displacement_tonnage_ldt::text as light_displacement_tonnage_ldt | legacy_data.light_displacement_tonnage_ldt::text |
| 15 | length_overall | - | length_overall | - | legacy_data.length_overall::text as length_overall | legacy_data.length_overall::text |
| 16 | length_bp | - | length_bp | - | legacy_data.length_bp::text as length_bp | legacy_data.length_bp::text |
| 17 | breadth_moulded | - | breadth_moulded | - | legacy_data.breadth_moulded::text as breadth_moulded | legacy_data.breadth_moulded::text |
| 18 | draught | - | draught | - | legacy_data.draught::text as draught | legacy_data.draught::text |
| 19 | depth | - | depth | - | legacy_data.depth::text as depth | legacy_data.depth::text |
| 20 | displacement | - | displacement | - | legacy_data.displacement::text as displacement | legacy_data.displacement::text |
| 21 | grain | - | grain | - | legacy_data.grain::text as grain | legacy_data.grain::text |
| 22 | bale | - | bale | - | legacy_data.bale::text as bale | legacy_data.bale::text |
| 23 | liquid | - | liquid | - | legacy_data.liquid::text as liquid | legacy_data.liquid::text |
| 24 | gas | - | gas | - | legacy_data.gas::text as gas | legacy_data.gas::text |
| 25 | teu | - | teu | - | legacy_data.teu::text as teu | legacy_data.teu::text |
| 26 | teu_t | - | teu_t | - | legacy_data.teu_t::text as teu_t | legacy_data.teu_t::text |
| 27 | year_of_build | - | year_of_build | - | NULLIF(TRIM(legacy_data.year_of_build), '') as year_of_build | NULLIF(TRIM(legacy_data.year_of_build), '') |
| 28 | created_by_id | - | created_by_id | - | NULLIF(TRIM(legacy_data.created_by_id), '') as created_by_id | NULLIF(TRIM(legacy_data.created_by_id), '') |
| 29 | updated_by_id | - | updated_by_id | - | NULLIF(TRIM(legacy_data.updated_by_id), '') as updated_by_id | NULLIF(TRIM(legacy_data.updated_by_id), '') |
| 30 | isdeleted | - | isdeleted | - | CASE WHEN legacy_data.isdeleted THEN 'true' ELSE 'false' END as isdeleted | CASE WHEN legacy_data.isdeleted THEN 'true' ELSE 'false' END |
| 31 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 32 | - | - | parent_id | - | NULL | NULL::uuid |
| 33 | derived | - | version | - | 1 as version | 1 |
| 34 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 35 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 36 | isdeleted, updated_at, created_at | - | deleted_at | - | CASE WHEN legacy_data.isdeleted THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END as deleted_at | CASE WHEN legacy_data.isdeleted THEN COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) ELSE NULL END |
| 37 | - | - | archived_at | - | NULL | NULL::timestamp |
| 38 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULLIF(TRIM(legacy_data.created_by_id), '')::varchar, NULL::varchar, NULLIF(TRIM(legacy_data.updated_by_id), '')::varchar, NULL::varchar, NULL::varch... |
| 39 | - | - | level | - | NULL | NULL::numeric |
| 40 | - | - | tags | - | NULL | NULL::text[] |
| 41 | isdeleted, status | - | status | - | CASE WHEN legacy_data.isdeleted THEN 3 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'DRAFT' THEN 1 W... | CASE WHEN legacy_data.isdeleted THEN 3 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(legacy_data.status, ''))) = 'DRAFT' THEN 1 W... |
| 42 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 43 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/add_on_vessels_migration.sql`

## Validation

- Run `05-validation/master/add_on_vessels_validation.sql` if available
- Run `06-rollback/master/add_on_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
