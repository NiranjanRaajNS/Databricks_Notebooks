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

- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID in SAC)
- `code` generated from `ship_name` via `generate_meaningful_code(ship_name, id::text)`
- `status` derived from `isdeleted` (takes precedence) then `status` string mapping
- `deleted_at` set from timestamps when `isdeleted = true`
- Filter: `ship_name IS NOT NULL AND TRIM(ship_name) <> ''`
- Numeric FK columns cast to text in SMAC target

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.add_on_vessels` before insert (full table reload).
- Orchestration dependencies: `countries`, `flags`, `ports`, `categories`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; SAC bigint id only |
| 2 | `ship_name, id` | character varying, bigint | `code` | text | `generate_meaningful_code(TRIM(ship_name), id::text)` | Generated code; NOT NULL |
| 3 | `ship_name` | character varying | `name` | text | `TRIM(ship_name)` | NOT NULL |
| 4 | `vessel_id` | uuid | `vessel_id` | text | `vessel_id::text` | UUID cast to text |
| 5 | `ship_name` | character varying | `ship_name` | text | `TRIM(ship_name)` | Direct copy |
| 6 | `imo_no` | bigint | `imo_no` | text | `imo_no::text` | Numeric cast to text |
| 7 | `shiptype` | character varying | `shiptype` | text | `NULLIF(TRIM(shiptype), '')` | Direct copy |
| 8 | `shiptype_synergy` | bigint | `shiptype_synergy` | text | `shiptype_synergy::text` | Numeric cast to text |
| 9 | `flag` | bigint | `flag` | text | `flag::text` | Numeric cast to text |
| 10 | `port_of_registry` | bigint | `port_of_registry` | text | `port_of_registry::text` | Numeric cast to text |
| 11 | `gross` | integer | `gross` | text | `gross::text` | Numeric cast to text |
| 12 | `net_tonnage_nt` | integer | `net_tonnage_nt` | text | `net_tonnage_nt::text` | Numeric cast to text |
| 13 | `deadweight` | integer | `deadweight` | text | `deadweight::text` | Numeric cast to text |
| 14 | `light_displacement_tonnage_ldt` | integer | `light_displacement_tonnage_ldt` | text | `light_displacement_tonnage_ldt::text` | Numeric cast to text |
| 15 | `length_overall` | numeric | `length_overall` | text | `length_overall::text` | Numeric cast to text |
| 16 | `length_bp` | numeric | `length_bp` | text | `length_bp::text` | Numeric cast to text |
| 17 | `breadth_moulded` | numeric | `breadth_moulded` | text | `breadth_moulded::text` | Numeric cast to text |
| 18 | `draught` | numeric | `draught` | text | `draught::text` | Numeric cast to text |
| 19 | `depth` | numeric | `depth` | text | `depth::text` | Numeric cast to text |
| 20 | `displacement` | integer | `displacement` | text | `displacement::text` | Numeric cast to text |
| 21 | `grain` | integer | `grain` | text | `grain::text` | Numeric cast to text |
| 22 | `bale` | integer | `bale` | text | `bale::text` | Numeric cast to text |
| 23 | `liquid` | integer | `liquid` | text | `liquid::text` | Numeric cast to text |
| 24 | `gas` | integer | `gas` | text | `gas::text` | Numeric cast to text |
| 25 | `teu` | integer | `teu` | text | `teu::text` | Numeric cast to text |
| 26 | `teu_t` | integer | `teu_t` | text | `teu_t::text` | Numeric cast to text |
| 27 | `year_of_build` | character varying | `year_of_build` | text | `NULLIF(TRIM(year_of_build), '')` | Direct copy |
| 28 | `created_by_id` | character varying | `created_by_id` | text | `NULLIF(TRIM(created_by_id), '')` | Direct copy |
| 29 | `updated_by_id` | character varying | `updated_by_id` | text | `NULLIF(TRIM(updated_by_id), '')` | Direct copy |
| 30 | `isdeleted` | boolean | `isdeleted` | text | `'true'` / `'false'` from boolean | Stored as text in SMAC |
| 31 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 32 | `—` | — | `parent_id` | uuid | `NULL` | No source equivalent |
| 33 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 34 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 35 | `updated_at, created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 36 | `isdeleted, updated_at, created_at` | boolean, timestamp without time zone | `deleted_at` | timestamp without time zone | Set to `COALESCE(updated_at, created_at, NOW())` when `isdeleted = true`; else `NULL` | Derived soft-delete timestamp |
| 37 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | No source equivalent |
| 38 | `created_by_id, updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` from created/updated by IDs | No `legacy_id` (handled by `id_mappings`) |
| 39 | `—` | — | `level` | numeric | `NULL` | Not populated |
| 40 | `—` | — | `tags` | text[] | `NULL` | Not populated |
| 41 | `isdeleted, status` | boolean, character varying | `status` | integer | `isdeleted` → Deleted (3); else map status string ACTIVE/DRAFT/INACTIVE/DELETED | `isdeleted` takes precedence |
| 42 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 43 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`
- `countries`
- `flags`
- `ports`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/add_on_vessels_migration.sql`

## Validation

- Run `05-validation/master/add_on_vessels_validation.sql` if available
- Run `06-rollback/master/add_on_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
