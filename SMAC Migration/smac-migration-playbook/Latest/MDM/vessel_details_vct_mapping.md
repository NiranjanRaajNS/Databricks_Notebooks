# Table Mapping: vessel_details_vct → vct_requests

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details_vct
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vct_requests
- **Source Script**: `04-migration-scripts/master/vessel_details_vct_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details_vct`
- **New Path**: `smac_master_migration.vessel.vct_requests`

## Business Key

- **Composite Key**: (`requester_id`, `created_at`)
- **Source (orchestration)**: VCT Requests (`vessel_details_vct` → `vct_requests`)

## Migration Notes

- Source: `synergy_vessel.public.vessel_details_vct` LEFT JOIN `vessel_particulars_vct` → `vessel.vct_requests`
- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Mappings auto-stored by `migration.resolve_target_id()` in `migration.table_mappings`
- ~80 scalar vessel attributes unpivoted into `field_json` JSONB array via `sac_column_to_field_id_lookup`
- `service_type` integer (1–4) mapped to SMAC `public.service_types` UUID array in `values` field
- `vessel_id` backfilled via `vessel_details_to_vessel_mapping` (IMO number or name match); nullable
- `vessel_revision_id` from `vessel_revision_id_mapping` on `identifier` UUID; nullable
- `vct_status` derived from OT/final approval/rejection fields and `deleted_at`
- Filter: `requester_id IS NOT NULL`
- Migrate ALL records including deleted (per Rule 2.6)

## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Uses `DISTINCT ON (id)` when staging legacy data with `vessel_particulars_vct` join
- Stores all vessel details in `field_json` JSONB
- Script performs `TRUNCATE TABLE vessel.vct_requests` before insert (full table reload)
- Orchestration dependencies: optional FK backfill via `vessels`, `vessel_revisions`; `field_json` FK remapping requires master tables (categories, flags, ports, classes, owners, companies, service_types, etc.)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 21

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_details_to_vessel_mapping` | Backfill `vessel_id` by IMO number or name match | `legacy_vct_id`, `legacy_imo_number`, `legacy_name`, `new_vessel_id` | - | `synergy_vessel` |
| `vessel_revision_id_mapping` | FK lookup | `legacy_identifier`, `new_revision_id` | `migration.table_mappings` (see SQL) | - |
| `flag_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `class_id_mapping` | FK lookup | `legacy_class_id`, `new_class_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_category_id_mapping` | FK lookup | `source_category_id`, `target_category_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_sub_category_id_mapping` | FK lookup | `source_sub_category_id`, `target_sub_category_id` | `migration.table_mappings` (see SQL) | - |
| `ecdis_type_id_mapping` | FK lookup | `legacy_ecdis_type_id`, `new_ecdis_type_id` | `migration.table_mappings` (see SQL) | - |
| `mlc_company_id_mapping` | FK lookup | `legacy_mlc_company_id`, `new_mlc_company_id` | `?.?.mlc_master` → `?.?.companies` | - |
| `ship_management_company_id_mapping` | FK lookup | `legacy_ship_management_company_id`, `new_ship_management_company_id` | `?.?.ship_management_companies` → `?.?.companies` | - |
| `group_company_id_mapping` | FK lookup | `legacy_group_company_id`, `new_group_company_id` | `?.?.ship_management_companies` → `?.?.companies` | - |
| `service_type_crewing_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_technical_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_procurement_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_accounting_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_mlc_lookup` | FK lookup | `service_type_id` | - | - |
| `owner_id_mapping` | FK lookup | `legacy_owner_id`, `new_owner_id` | `?.?.vessel_owners` → `?.?.owners` | - |
| `register_owner_id_mapping` | FK lookup | `legacy_register_owner_id`, `new_register_owner_id` | `?.?.vessel_registered_owners` → `?.?.owners` | - |
| `bare_boat_owner_id_mapping` | FK lookup | `legacy_bare_boat_owner_id_uuid`, `new_bare_boat_owner_id` | `?.?.vessel_bare_boat_owner` → `?.?.owners` | - |
| `sac_column_to_field_id_lookup` | FK lookup | `sac_column_name`, `field_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: legacy_vessel_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `vessel_details_to_vessel_mapping`

- **Purpose**: Backfill `vessel_id` by IMO number or name match
- **Output columns**: legacy_vct_id, legacy_imo_number, legacy_name, new_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessel_mapping AS
SELECT DISTINCT
    vdct.id::bigint AS legacy_vct_id,
    vdct.imo_number AS legacy_imo_number,
    vdct.name AS legacy_name,
    v.id AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, imo_number, name FROM public.vessel_details_vct WHERE imo_number IS NOT NULL OR name IS NOT NULL'
) AS vdct(id bigint, imo_number bigint, name varchar)
LEFT JOIN vessel.vessels v ON
    (vdct.imo_number IS NOT NULL AND v.imo_number = vdct.imo_number::text)
    OR (vdct.imo_number IS NULL AND vdct.name IS NOT NULL AND UPPER(TRIM(v.name)) = UPPER(TRIM(vdct.name)));
```

### `vessel_revision_id_mapping`

- **Output columns**: legacy_identifier, new_revision_id
- **migration.table_mappings**: target_table=vessel_revisions

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_identifier,
    target_id AS new_revision_id
FROM migration.table_mappings
WHERE target_table = 'vessel_revisions'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### `flag_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=flags
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    COALESCE(tm.target_id, f.identifier)::uuid AS new_id
FROM dblink('synergy_vessel', 'SELECT id, identifier FROM public.flags') AS f(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = f.identifier::text AND tm.target_table = 'flags' AND tm.target_db = current_database();
```

### `port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=port_of_registry
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT
    p.id::bigint AS legacy_id,
    por_map.target_id AS new_id
FROM dblink('synergy_vessel', 'SELECT id, identifier FROM public.ports') AS p(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings por_map ON por_map.source_id = p.identifier::text AND por_map.target_table = 'port_of_registry' AND por_map.target_db = current_database();
```

### `class_id_mapping`

- **Output columns**: legacy_class_id, new_class_id
- **migration.table_mappings**: target_table=classes

```sql
CREATE TEMP TABLE class_id_mapping AS
SELECT
    source_id::bigint AS legacy_class_id,
    target_id AS new_class_id
FROM migration.table_mappings
WHERE target_table = 'classes' AND target_db = current_database();
```

### `vessel_category_id_mapping`

- **Output columns**: source_category_id, target_category_id
- **migration.table_mappings**: target_table=categories

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories' AND target_db = current_database();
```

### `vessel_sub_category_id_mapping`

- **Output columns**: source_sub_category_id, target_sub_category_id
- **migration.table_mappings**: target_table=sub_categories

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories' AND target_db = current_database();
```

### `ecdis_type_id_mapping`

- **Output columns**: legacy_ecdis_type_id, new_ecdis_type_id
- **migration.table_mappings**: target_table=ecdis_types

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_ecdis_type_id,
    target_id AS new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types' AND target_db = current_database();
```

### `mlc_company_id_mapping`

- **Output columns**: legacy_mlc_company_id, new_mlc_company_id
- **migration.table_mappings**: source_table=mlc_master, target_table=companies

```sql
CREATE TEMP TABLE mlc_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_mlc_company_id,
    target_id AS new_mlc_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND source_table = 'mlc_master'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### `ship_management_company_id_mapping`

- **Output columns**: legacy_ship_management_company_id, new_ship_management_company_id
- **migration.table_mappings**: source_table=ship_management_companies, target_table=companies

```sql
CREATE TEMP TABLE ship_management_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_ship_management_company_id,
    target_id AS new_ship_management_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND source_table = 'ship_management_companies'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### `group_company_id_mapping`

- **Output columns**: legacy_group_company_id, new_group_company_id
- **migration.table_mappings**: source_table=ship_management_companies, target_table=companies

```sql
CREATE TEMP TABLE group_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_group_company_id,
    target_id AS new_group_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
  AND (source_table = 'ship_management_companies' OR source_table IS NULL)
ORDER BY source_id::bigint, CASE WHEN source_table = 'ship_management_companies' THEN 0 ELSE 1 END;
```

### `service_type_crewing_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### `service_type_technical_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### `service_type_procurement_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### `service_type_accounting_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

### `service_type_mlc_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_mlc_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'mlc ship owner'
LIMIT 1;
```

### `owner_id_mapping`

- **Output columns**: legacy_owner_id, new_owner_id
- **migration.table_mappings**: source_table=vessel_owners, target_table=owners

```sql
CREATE TEMP TABLE owner_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_owners'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### `register_owner_id_mapping`

- **Output columns**: legacy_register_owner_id, new_register_owner_id
- **migration.table_mappings**: source_table=vessel_registered_owners, target_table=owners

```sql
CREATE TEMP TABLE register_owner_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_register_owner_id,
    target_id AS new_register_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_registered_owners'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### `bare_boat_owner_id_mapping`

- **Output columns**: legacy_bare_boat_owner_id_uuid, new_bare_boat_owner_id
- **migration.table_mappings**: source_table=vessel_bare_boat_owner, target_table=owners

```sql
CREATE TEMP TABLE bare_boat_owner_id_mapping AS
SELECT DISTINCT ON (COALESCE(target_id::text, source_id::text))
    target_id AS legacy_bare_boat_owner_id_uuid,
    target_id AS new_bare_boat_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_bare_boat_owner'
  AND target_db = current_database()
ORDER BY COALESCE(target_id::text, source_id::text);
```

### `sac_column_to_field_id_lookup`

- **Output columns**: sac_column_name, field_id

```sql
CREATE TEMP TABLE IF NOT EXISTS sac_column_to_field_id_lookup AS
SELECT

    CASE
        WHEN 'VESSEL_NAME' = ANY(fd.tags) THEN 'name'
        WHEN 'IMO_NUMBER' = ANY(fd.tags) THEN 'imo_number'
        WHEN 'VESSELTYPE' = ANY(fd.tags) THEN 'vessel_category_id'
        WHEN 'VESSELSUBTYPE' = ANY(fd.tags) THEN 'vessel_sub_category_id'
        WHEN 'VESSEL_CODE' = ANY(fd.tags) THEN 'vessel_code'
        WHEN 'OFFICIAL_NO' = ANY(fd.tags) THEN 'official_number'
        WHEN 'CALLSIGN' = ANY(fd.tags) THEN 'call_sign'
        WHEN 'MMSI_NUMBER' = ANY(fd.tags) THEN 'mmsi'
        WHEN 'FLAG' = ANY(fd.tags) THEN 'flag_id'
        WHEN 'PORT_OF_REGISTRY' = ANY(fd.tags) THEN 'port_id'
        WHEN 'TENTATIVE_TAKEOVER_DATE' = ANY(fd.tags) THEN 'takeover_date'
        WHEN 'VESSEL_CLASS_SOCIETY' = ANY(fd.tags) THEN 'vessel_class_id'
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id'
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'me_make_id'
        WHEN 'MAIN_ENGINE_MODEL' = ANY(fd.tags) THEN 'me_model_id'
        WHEN 'MAIN_ENGINE_MAX_CONT_RATING_KW' = ANY(fd.tags) THEN 'me_mcr_kw'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'me_is_electronic_engine'
     ...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier, id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `COALESCE(identifier::text, id::text)`; `p_target_id = identifier` | Preserves SAC identifier; idempotent via `id_mappings` |
| 2 | `~80 attribute columns` (`vessel_details_vct` + `vessel_particulars_vct`) | various | `field_json` | jsonb | `jsonb_agg` of `{fieldId, value, values, isOtherField}` via `sac_column_to_field_id_lookup`; FK remapping for categories, flags, ports, classes, owners, companies; `_other`/`_others` columns resolved via base field lookup | Unpivoted dynamic field storage |
| 3 | `requester_id` | uuid | `requester_id` | uuid | Direct copy | NOT NULL filter |
| 4 | `reporting_officer_id` | uuid | `reporting_officer_id` | uuid | Direct copy | Nullable |
| 5 | `remarks` | text | `remarks` | text | `TRIM(COALESCE(remarks, ''))` | Direct copy |
| 6 | `deleted_at, ot_rejected_by, rejected_by, ot_approved_by, approved_by` | timestamp, uuid | `vct_status` | integer | deleted→3; any rejection→3; both OT+final approved→2; OT approved only→1; final approved only→2; else 0 | Derived VCT workflow status |
| 7 | `imo_number, name` | bigint, varchar | `vessel_id` | uuid | `vessel_details_to_vessel_mapping.new_vessel_id` — match on IMO or `UPPER(TRIM(name))` | Nullable FK backfill |
| 8 | `identifier` | uuid | `vessel_revision_id` | uuid | `vessel_revision_id_mapping.new_revision_id` on identifier UUID | Nullable FK lookup |
| 9 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 10 | `—` | — | `parent_id` | uuid | `NULL` | Not populated |
| 11 | `—` | — | `level` | numeric | `NULL` | Not populated |
| 12 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 13 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Script uses literal 0 |
| 14 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Script uses literal 0 |
| 15 | `status, deleted_at` | character varying, timestamp | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule |
| 16 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 17 | `updated_at, created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Fallback chain |
| 18 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 19 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not populated |
| 20 | `audit_info, id` | jsonb, bigint | `audit_info` | jsonb | `migration.build_audit_info()` — extracts `created_by`/`updated_by` from legacy `audit_info` JSONB; `legacy_id` in `notes` | Standardized SMAC structure |
| 21 | `—` | — | `tags` | text[] | `NULL` | Not populated |

**`field_json` unpivoted source columns (main INSERT VALUES):**

`name`, `imo_number`, `vessel_category_id`, `vessel_sub_category_id`, `vessel_code`, `vessel_code_existing`, `official_number`, `call_sign`, `mmsi`, `flag_id`, `port_id`, `takeover_date`, `vessel_class_id`, `ecdis_type_id`, `me_make_id`, `me_model_id`, `me_mcr_kw`, `me_is_electronic_engine`, `dual_fuelship`, `register_owner_id`, `bare_boat_owner_id`, `mlc_company_id`, `ship_management_company_id`, `union_code`, `service_type`, `group_company_id`, `owner_id`, `advance_joiners_date`, `dtw`, `dead_weight`, `grt`, `gross_ton`, `ice_class`, `polar_code_applicable`, `class_no`, `group_company_code`, `ship_management_company_other`, `ship_management_company_address`, `mlc_company_other`, `mlc_company_address`, `manning_management_company`, `manning_management_company_other`, `manning_management_company_address`, `recruitment_company`, `recruitment_company_1`, `recruitment_company_2`, `recruitment_company_3`, `owner_other`, `owner_address`, `register_owner_other`, `register_owner_address`, `beneficiary_owner_id`, `bare_boat_owner_other`, `bare_boat_owner_address`, `ship_builder`, `yard_country_id`, `built_year`, `build_date`, `keel_laid`, `launched`, `delivered`, `handover_date`, `hull_number`, `vdr_make_id`, `cba_code_temp`, `vessel_group`, `sap_vessel_company_code`, `inactive_at`, `approval_level`, `ot_approval_remarks`, `ot_approved_by`, `ot_approved_by_name`, `ot_reason_for_rejection`, `ot_rejected_by`, `ot_rejected_by_name`, `approval_remarks`, `approved_by`, `approved_by_name`, `reason_for_rejection`, `rejected_by`, `rejected_by_name`, `sma_signing_entity_id`, `sma_signing_entity_name`, `sma_signing_entity_address`, `cba_display`, `cba_itf_type`

**SAC columns not migrated to scalar target columns:** `requester_id`, `reporting_officer_id`, `remarks`, `status`, `identifier`, `id`, `created_at`, `updated_at`, `deleted_at`, `audit_info` — mapped to dedicated SMAC columns; approval fields also stored in `field_json` and used to derive `vct_status`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`
- `vessel.field_definitions`
- `vessel.vessels` (optional backfill via IMO/name match)
- `vessel.vessel_revisions` (optional backfill via identifier mapping)
- Master tables for `field_json` FK remapping: `categories`, `sub_categories`, `flags`, `port_of_registry`, `classes`, `ecdis_types`, `companies`, `owners`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_vessel_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Vessel Details To Vessel ID Mapping
**Purpose**: Backfill `vessel_id` by IMO number or name match
**Output columns**: `legacy_vct_id, legacy_imo_number, legacy_name, new_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessel_mapping AS
SELECT DISTINCT
    vdct.id::bigint AS legacy_vct_id,
    vdct.imo_number AS legacy_imo_number,
    vdct.name AS legacy_name,
    v.id AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, imo_number, name FROM public.vessel_details_vct WHERE imo_number IS NOT NULL OR name IS NOT NULL'
) AS vdct(id bigint, imo_number bigint, name varchar)
LEFT JOIN vessel.vessels v ON
    (vdct.imo_number IS NOT NULL AND v.imo_number = vdct.imo_number::text)
    OR (vdct.imo_number IS NULL AND vdct.name IS NOT NULL AND UPPER(TRIM(v.name)) = UPPER(TRIM(vdct.name)));
```

### 3. Vessel Revision ID Mapping
**Output columns**: `legacy_identifier, new_revision_id`
**migration.table_mappings**: `target_table='vessel_revisions'`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT
    source_id::uuid AS legacy_identifier,
    target_id AS new_revision_id
FROM migration.table_mappings
WHERE target_table = 'vessel_revisions'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

### 4. Flag ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='flags'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    COALESCE(tm.target_id, f.identifier)::uuid AS new_id
FROM dblink('synergy_vessel', 'SELECT id, identifier FROM public.flags') AS f(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = f.identifier::text AND tm.target_table = 'flags' AND tm.target_db = current_database();
```

### 5. Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='port_of_registry'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT
    p.id::bigint AS legacy_id,
    por_map.target_id AS new_id
FROM dblink('synergy_vessel', 'SELECT id, identifier FROM public.ports') AS p(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings por_map ON por_map.source_id = p.identifier::text AND por_map.target_table = 'port_of_registry' AND por_map.target_db = current_database();
```

### 6. Class ID Mapping
**Output columns**: `legacy_class_id, new_class_id`
**migration.table_mappings**: `target_table='classes'`

```sql
CREATE TEMP TABLE class_id_mapping AS
SELECT
    source_id::bigint AS legacy_class_id,
    target_id AS new_class_id
FROM migration.table_mappings
WHERE target_table = 'classes' AND target_db = current_database();
```

### 7. Vessel Category ID Mapping
**Output columns**: `source_category_id, target_category_id`
**migration.table_mappings**: `target_table='categories'`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint AS source_category_id,
    target_id AS target_category_id
FROM migration.table_mappings
WHERE target_table = 'categories' AND target_db = current_database();
```

### 8. Vessel Sub Category ID Mapping
**Output columns**: `source_sub_category_id, target_sub_category_id`
**migration.table_mappings**: `target_table='sub_categories'`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    source_id::bigint AS source_sub_category_id,
    target_id AS target_sub_category_id
FROM migration.table_mappings
WHERE target_table = 'sub_categories' AND target_db = current_database();
```

### 9. Ecdis Type ID Mapping
**Output columns**: `legacy_ecdis_type_id, new_ecdis_type_id`
**migration.table_mappings**: `target_table='ecdis_types'`

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint AS legacy_ecdis_type_id,
    target_id AS new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types' AND target_db = current_database();
```

### 10. Mlc Company ID Mapping
**Output columns**: `legacy_mlc_company_id, new_mlc_company_id`
**migration.table_mappings**: `mlc_master` → `companies`

```sql
CREATE TEMP TABLE mlc_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_mlc_company_id,
    target_id AS new_mlc_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND source_table = 'mlc_master'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### 11. Ship Management Company ID Mapping
**Output columns**: `legacy_ship_management_company_id, new_ship_management_company_id`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE ship_management_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_ship_management_company_id,
    target_id AS new_ship_management_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND source_table = 'ship_management_companies'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### 12. Group Company ID Mapping
**Output columns**: `legacy_group_company_id, new_group_company_id`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE group_company_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_group_company_id,
    target_id AS new_group_company_id
FROM migration.table_mappings
WHERE target_table = 'companies'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
  AND (source_table = 'ship_management_companies' OR source_table IS NULL)
ORDER BY source_id::bigint, CASE WHEN source_table = 'ship_management_companies' THEN 0 ELSE 1 END;
```

### 13. Service Type Crewing ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### 14. Service Type Technical ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### 15. Service Type Procurement ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### 16. Service Type Accounting ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

### 17. Service Type Mlc ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_mlc_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'mlc ship owner'
LIMIT 1;
```

### 18. Owner ID Mapping
**Output columns**: `legacy_owner_id, new_owner_id`
**migration.table_mappings**: `vessel_owners` → `owners`

```sql
CREATE TEMP TABLE owner_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_owner_id,
    target_id AS new_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_owners'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### 19. Register Owner ID Mapping
**Output columns**: `legacy_register_owner_id, new_register_owner_id`
**migration.table_mappings**: `vessel_registered_owners` → `owners`

```sql
CREATE TEMP TABLE register_owner_id_mapping AS
SELECT DISTINCT ON (source_id::bigint)
    source_id::bigint AS legacy_register_owner_id,
    target_id AS new_register_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_registered_owners'
  AND target_db = current_database()
  AND source_id ~ '^\d+$'
ORDER BY source_id::bigint;
```

### 20. Bare Boat Owner ID Mapping
**Output columns**: `legacy_bare_boat_owner_id_uuid, new_bare_boat_owner_id`
**migration.table_mappings**: `vessel_bare_boat_owner` → `owners`

```sql
CREATE TEMP TABLE bare_boat_owner_id_mapping AS
SELECT DISTINCT ON (COALESCE(target_id::text, source_id::text))
    target_id AS legacy_bare_boat_owner_id_uuid,
    target_id AS new_bare_boat_owner_id
FROM migration.table_mappings
WHERE target_table = 'owners'
  AND source_table = 'vessel_bare_boat_owner'
  AND target_db = current_database()
ORDER BY COALESCE(target_id::text, source_id::text);
```

### 21. Sac Column To Field Id ID Mapping
**Output columns**: `sac_column_name, field_id`

```sql
CREATE TEMP TABLE IF NOT EXISTS sac_column_to_field_id_lookup AS
SELECT

    CASE
        WHEN 'VESSEL_NAME' = ANY(fd.tags) THEN 'name'
        WHEN 'IMO_NUMBER' = ANY(fd.tags) THEN 'imo_number'
        WHEN 'VESSELTYPE' = ANY(fd.tags) THEN 'vessel_category_id'
        WHEN 'VESSELSUBTYPE' = ANY(fd.tags) THEN 'vessel_sub_category_id'
        WHEN 'VESSEL_CODE' = ANY(fd.tags) THEN 'vessel_code'
        WHEN 'OFFICIAL_NO' = ANY(fd.tags) THEN 'official_number'
        WHEN 'CALLSIGN' = ANY(fd.tags) THEN 'call_sign'
        WHEN 'MMSI_NUMBER' = ANY(fd.tags) THEN 'mmsi'
        WHEN 'FLAG' = ANY(fd.tags) THEN 'flag_id'
        WHEN 'PORT_OF_REGISTRY' = ANY(fd.tags) THEN 'port_id'
        WHEN 'TENTATIVE_TAKEOVER_DATE' = ANY(fd.tags) THEN 'takeover_date'
        WHEN 'VESSEL_CLASS_SOCIETY' = ANY(fd.tags) THEN 'vessel_class_id'
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id'
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'me_make_id'
        WHEN 'MAIN_ENGINE_MODEL' = ANY(fd.tags) THEN 'me_model_id'
        WHEN 'MAIN_ENGINE_MAX_CONT_RATING_KW' = ANY(fd.tags) THEN 'me_mcr_kw'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'me_is_electronic_engine'
        WHEN 'DUAL_FUEL' = ANY(fd.tags) THEN 'dual_fuelship'
        WHEN 'REGISTERED_OWNER' = ANY(fd.tags) THEN 'register_owner_id'
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        WHEN 'MLC_SHIP_OWNER' = ANY(fd.tags) THEN 'mlc_company_id'
        WHEN 'DOC_COMPANY' = ANY(fd.tags) THEN 'ship_management_company_id'
        WHEN 'UNION_TERMS' = ANY(fd.tags) THEN 'union_code'
        WHEN 'MANAGEMENT_SERVICE_TYPE' = ANY(fd.tags) THEN 'service_type'
        WHEN 'GROUP_OWNER' = ANY(fd.tags) THEN 'group_company_id'
        WHEN 'GROUP_CUSTOMER_GROUP_OWNER_NAME' = ANY(fd.tags) THEN 'owner_id'
        WHEN 'ADVANCE_JOINERS_DATE' = ANY(fd.tags) THEN 'advance_joiners_date'
        WHEN 'DWT' = ANY(fd.tags) THEN 'dtw'
        WHEN 'GRT' = ANY(fd.tags) THEN 'grt'
        WHEN 'BENEFICIARY_OWNER' = ANY(fd.tags) THEN 'beneficiary_owner_id'
        WHEN 'BUILD_DATE' = ANY(fd.tags) THEN 'build_date'
        WHEN 'BUILT_YEAR' = ANY(fd.tags) THEN 'built_year'
        WHEN 'CLASS_NO' = ANY(fd.tags) THEN 'class_no'
        WHEN 'DELIVERED' = ANY(fd.tags) THEN 'delivered'
        WHEN 'HANDOVER_DATE' = ANY(fd.tags) THEN 'handover_date'
        WHEN 'HULL_NUMBER' = ANY(fd.tags) THEN 'hull_number'
        WHEN 'ICE_CLASS' = ANY(fd.tags) THEN 'ice_class'
        WHEN 'KEEL_LAID' = ANY(fd.tags) THEN 'keel_laid'
        WHEN 'LAUNCHED' = ANY(fd.tags) THEN 'launched'
        WHEN 'MANNING_MANAGEMENT_COMPANY' = ANY(fd.tags) THEN 'manning_management_company'
        WHEN 'P_AND_I' = ANY(fd.tags) THEN 'p_and_i'
        WHEN 'POLAR_CODE_APPLICABLE' = ANY(fd.tags) THEN 'polar_code_applicable'
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company'
        WHEN 'SHIP_BUILDER' = ANY(fd.tags) THEN 'ship_builder'
        WHEN 'VDR_MAKE' = ANY(fd.tags) THEN 'vdr_make_id'
        WHEN 'VESSEL_GROUP' = ANY(fd.tags) THEN 'vessel_group'
        WHEN 'YARD_COUNTRY' = ANY(fd.tags) THEN 'yard_country_id'
        WHEN 'GROUP_COMPANY_CODE' = ANY(fd.tags) THEN 'group_company_code'

        WHEN 'GROUP_CUSTOMER_OWNER_ADDRESS' = ANY(fd.tags) THEN 'owner_address'
        WHEN 'REG_OWNER_ADDRESS' = ANY(fd.tags) THEN 'register_owner_address'
        WHEN 'CUSTOMER_SIGNING_ENTITY_ADDRESS' = ANY(fd.tags) THEN 'bare_boat_owner_address'
        WHEN 'MLC_SHIP_OWNER_ADDRESS' = ANY(fd.tags) THEN 'mlc_company_address'
        WHEN 'DOC_HOLDER_ADDRESS' = ANY(fd.tags) THEN 'ship_management_company_address'
        ELSE NULL
    END AS sac_column_name,

    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND (
    'VESSEL_NAME' = ANY(fd.tags) OR
    'IMO_NUMBER' = ANY(fd.tags) OR
    'VESSELTYPE' = ANY(fd.tags) OR
    'VESSELSUBTYPE' = ANY(fd.tags) OR
    'VESSEL_CODE' = ANY(fd.tags) OR
    'OFFICIAL_NO' = ANY(fd.tags) OR
    'CALLSIGN' = ANY(fd.tags) OR
    'MMSI_NUMBER' = ANY(fd.tags) OR
    'FLAG' = ANY(fd.tags) OR
    'PORT_OF_REGISTRY' = ANY(fd.tags) OR
    'TENTATIVE_TAKEOVER_DATE' = ANY(fd.tags) OR
    'VESSEL_CLASS_SOCIETY' = ANY(fd.tags) OR
    'ECDIS_TYPE' = ANY(fd.tags) OR
    'MAIN_ENGINE_MAKE' = ANY(fd.tags) OR
    'MAIN_ENGINE_MODEL' = ANY(fd.tags) OR
    'MAIN_ENGINE_MAX_CONT_RATING_KW' = ANY(fd.tags) OR
    'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) OR
    'DUAL_FUEL' = ANY(fd.tags) OR
    'REGISTERED_OWNER' = ANY(fd.tags) OR
    'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) OR
    'MLC_SHIP_OWNER' = ANY(fd.tags) OR
    'DOC_COMPANY' = ANY(fd.tags) OR
    'UNION_TERMS' = ANY(fd.tags) OR
    'MANAGEMENT_SERVICE_TYPE' = ANY(fd.tags) OR
    'GROUP_OWNER' = ANY(fd.tags) OR
    'GROUP_CUSTOMER_GROUP_OWNER_NAME' = ANY(fd.tags) OR
    'ADVANCE_JOINERS_DATE' = ANY(fd.tags) OR
    'DWT' = ANY(fd.tags) OR
    'GRT' = ANY(fd.tags) OR
    'BENEFICIARY_OWNER' = ANY(fd.tags) OR
    'BUILD_DATE' = ANY(fd.tags) OR
    'BUILT_YEAR' = ANY(fd.tags) OR
    'CLASS_NO' = ANY(fd.tags) OR
    'DELIVERED' = ANY(fd.tags) OR
    'HANDOVER_DATE' = ANY(fd.tags) OR
    'HULL_NUMBER' = ANY(fd.tags) OR
    'ICE_CLASS' = ANY(fd.tags) OR
    'KEEL_LAID' = ANY(fd.tags) OR
    'LAUNCHED' = ANY(fd.tags) OR
    'MANNING_MANAGEMENT_COMPANY' = ANY(fd.tags) OR
    'P_AND_I' = ANY(fd.tags) OR
    'POLAR_CODE_APPLICABLE' = ANY(fd.tags) OR
    'RECRUITMENT_COMPANY' = ANY(fd.tags) OR
    'SHIP_BUILDER' = ANY(fd.tags) OR
    'VDR_MAKE' = ANY(fd.tags) OR
    'VESSEL_GROUP' = ANY(fd.tags) OR
    'YARD_COUNTRY' = ANY(fd.tags) OR
    'GROUP_COMPANY_CODE' = ANY(fd.tags) OR
    'GROUP_CUSTOMER_OWNER_ADDRESS' = ANY(fd.tags) OR
    'REG_OWNER_ADDRESS' = ANY(fd.tags) OR
    'CUSTOMER_SIGNING_ENTITY_ADDRESS' = ANY(fd.tags) OR
    'MLC_SHIP_OWNER_ADDRESS' = ANY(fd.tags) OR
    'DOC_HOLDER_ADDRESS' = ANY(fd.tags)
  )
  AND CASE
        WHEN 'VESSEL_NAME' = ANY(fd.tags) THEN 'name'
        WHEN 'IMO_NUMBER' = ANY(fd.tags) THEN 'imo_number'
        WHEN 'VESSELTYPE' = ANY(fd.tags) THEN 'vessel_category_id'
        WHEN 'VESSELSUBTYPE' = ANY(fd.tags) THEN 'vessel_sub_category_id'
        WHEN 'VESSEL_CODE' = ANY(fd.tags) THEN 'vessel_code'
        WHEN 'OFFICIAL_NO' = ANY(fd.tags) THEN 'official_number'
        WHEN 'CALLSIGN' = ANY(fd.tags) THEN 'call_sign'
        WHEN 'MMSI_NUMBER' = ANY(fd.tags) THEN 'mmsi'
        WHEN 'FLAG' = ANY(fd.tags) THEN 'flag_id'
        WHEN 'PORT_OF_REGISTRY' = ANY(fd.tags) THEN 'port_id'
        WHEN 'TENTATIVE_TAKEOVER_DATE' = ANY(fd.tags) THEN 'takeover_date'
        WHEN 'VESSEL_CLASS_SOCIETY' = ANY(fd.tags) THEN 'vessel_class_id'
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id'
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'me_make_id'
        WHEN 'MAIN_ENGINE_MODEL' = ANY(fd.tags) THEN 'me_model_id'
        WHEN 'MAIN_ENGINE_MAX_CONT_RATING_KW' = ANY(fd.tags) THEN 'me_mcr_kw'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'me_is_electronic_engine'
        WHEN 'DUAL_FUEL' = ANY(fd.tags) THEN 'dual_fuelship'
        WHEN 'REGISTERED_OWNER' = ANY(fd.tags) THEN 'register_owner_id'
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        WHEN 'MLC_SHIP_OWNER' = ANY(fd.tags) THEN 'mlc_company_id'
        WHEN 'DOC_COMPANY' = ANY(fd.tags) THEN 'ship_management_company_id'
        WHEN 'UNION_TERMS' = ANY(fd.tags) THEN 'union_code'
        WHEN 'MANAGEMENT_SERVICE_TYPE' = ANY(fd.tags) THEN 'service_type'
        WHEN 'GROUP_OWNER' = ANY(fd.tags) THEN 'group_company_id'
        WHEN 'GROUP_CUSTOMER_GROUP_OWNER_NAME' = ANY(fd.tags) THEN 'owner_id'
        WHEN 'ADVANCE_JOINERS_DATE' = ANY(fd.tags) THEN 'advance_joiners_date'
        WHEN 'DWT' = ANY(fd.tags) THEN 'dtw'
        WHEN 'GRT' = ANY(fd.tags) THEN 'grt'
        WHEN 'BENEFICIARY_OWNER' = ANY(fd.tags) THEN 'beneficiary_owner_id'
        WHEN 'BUILD_DATE' = ANY(fd.tags) THEN 'build_date'
        WHEN 'BUILT_YEAR' = ANY(fd.tags) THEN 'built_year'
        WHEN 'CLASS_NO' = ANY(fd.tags) THEN 'class_no'
        WHEN 'DELIVERED' = ANY(fd.tags) THEN 'delivered'
        WHEN 'HANDOVER_DATE' = ANY(fd.tags) THEN 'handover_date'
        WHEN 'HULL_NUMBER' = ANY(fd.tags) THEN 'hull_number'
        WHEN 'ICE_CLASS' = ANY(fd.tags) THEN 'ice_class'
        WHEN 'KEEL_LAID' = ANY(fd.tags) THEN 'keel_laid'
        WHEN 'LAUNCHED' = ANY(fd.tags) THEN 'launched'
        WHEN 'MANNING_MANAGEMENT_COMPANY' = ANY(fd.tags) THEN 'manning_management_company'
        WHEN 'P_AND_I' = ANY(fd.tags) THEN 'p_and_i'
        WHEN 'POLAR_CODE_APPLICABLE' = ANY(fd.tags) THEN 'polar_code_applicable'
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company'
        WHEN 'SHIP_BUILDER' = ANY(fd.tags) THEN 'ship_builder'
        WHEN 'VDR_MAKE' = ANY(fd.tags) THEN 'vdr_make_id'
        WHEN 'VESSEL_GROUP' = ANY(fd.tags) THEN 'vessel_group'
        WHEN 'YARD_COUNTRY' = ANY(fd.tags) THEN 'yard_country_id'
        WHEN 'GROUP_COMPANY_CODE' = ANY(fd.tags) THEN 'group_company_code'
        WHEN 'GROUP_CUSTOMER_OWNER_ADDRESS' = ANY(fd.tags) THEN 'owner_address'
        WHEN 'REG_OWNER_ADDRESS' = ANY(fd.tags) THEN 'register_owner_address'
        WHEN 'CUSTOMER_SIGNING_ENTITY_ADDRESS' = ANY(fd.tags) THEN 'bare_boat_owner_address'
        WHEN 'MLC_SHIP_OWNER_ADDRESS' = ANY(fd.tags) THEN 'mlc_company_address'
        WHEN 'DOC_HOLDER_ADDRESS' = ANY(fd.tags) THEN 'ship_management_company_address'
        ELSE NULL
      END IS NOT NULL
UNION ALL

SELECT
    CASE
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags)
  AND CASE
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        ELSE NULL
      END IS NOT NULL
UNION ALL

SELECT
    CASE
        WHEN 'DWT' = ANY(fd.tags) THEN 'dead_weight'
        WHEN 'GRT' = ANY(fd.tags) THEN 'gross_ton'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND ('DWT' = ANY(fd.tags) OR 'GRT' = ANY(fd.tags))
  AND CASE
        WHEN 'DWT' = ANY(fd.tags) THEN 'dead_weight'
        WHEN 'GRT' = ANY(fd.tags) THEN 'gross_ton'
        ELSE NULL
      END IS NOT NULL
UNION ALL

SELECT
    CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_1'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'RECRUITMENT_COMPANY' = ANY(fd.tags)
  AND CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_1'
        ELSE NULL
      END IS NOT NULL
UNION ALL
SELECT
    CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_2'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'RECRUITMENT_COMPANY' = ANY(fd.tags)
  AND CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_2'
        ELSE NULL
      END IS NOT NULL
UNION ALL
SELECT
    CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_3'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'RECRUITMENT_COMPANY' = ANY(fd.tags)
  AND CASE
        WHEN 'RECRUITMENT_COMPANY' = ANY(fd.tags) THEN 'recruitment_company_3'
        ELSE NULL
      END IS NOT NULL
UNION ALL

SELECT
    CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_1'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'ECDIS_TYPE' = ANY(fd.tags)
  AND CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_1'
        ELSE NULL
      END IS NOT NULL
UNION ALL
SELECT
    CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_2'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'ECDIS_TYPE' = ANY(fd.tags)
  AND CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_2'
        ELSE NULL
      END IS NOT NULL
UNION ALL
SELECT
    CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_3'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'ECDIS_TYPE' = ANY(fd.tags)
  AND CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_3'
        ELSE NULL
      END IS NOT NULL
UNION ALL
SELECT
    CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_4'
        ELSE NULL
    END AS sac_column_name,
    fd.id AS field_id
FROM vessel.field_definitions fd
WHERE fd.deleted_at IS NULL
  AND 'ECDIS_TYPE' = ANY(fd.tags)
  AND CASE
        WHEN 'ECDIS_TYPE' = ANY(fd.tags) THEN 'ecdis_type_id_4'
        ELSE NULL
      END IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/vessel_details_vct_migration.sql`

## Validation

- Run `05-validation/master/vessel_details_vct_validation.sql` if available
- Run `06-rollback/master/vessel_details_vct_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
