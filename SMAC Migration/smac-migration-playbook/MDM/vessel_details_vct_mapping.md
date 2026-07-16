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

- Uses migration.resolve_target_id() to preserve legacy identifier (UUID) as id when available
- Mappings are automatically stored in migration.table_mappings by migration.resolve_target_id()
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Joins with vessel_particulars_vct for additional fields
- Migrates vessel_details_vct to vct_requests. Preserves identifier UUID as id when available. Stores all vessel details and vessel_particulars_vct fields in field_json JSONB. Maps vct_status from approval fields: Draft=0, PendingApproval=1, Approved=2, Rejected=3. Maps requester_id and reporting_officer_id directly. Maps status (varchar) to status (integer) with deleted_at precedence. vessel_id and vessel_revision_id are nullable and may be NULL if mapping cannot be determined.

## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Stores all vessel details in field_json JSONB
- Script performs `TRUNCATE TABLE vessel.vct_requests` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 21

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_details_to_vessel_mapping` | Drop temp objects from a prior migration in | `legacy_vct_id`, `legacy_imo_number`, `legacy_name`, `new_vessel_id` | - | `synergy_vessel` |
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
| `service_type_mlc_lookup` | MLC Company ID mapping: mlc_company | `service_type_id` | - | - |
| `owner_id_mapping` | FK lookup | `legacy_owner_id`, `new_owner_id` | `?.?.vessel_owners` → `?.?.owners` | - |
| `register_owner_id_mapping` | FK lookup | `legacy_register_owner_id`, `new_register_owner_id` | `?.?.vessel_registered_owners` → `?.?.owners` | - |
| `bare_boat_owner_id_mapping` | FK lookup | `legacy_bare_boat_owner_id_uuid`, `new_bare_boat_owner_id` | `?.?.vessel_bare_boat_owner` → `?.?.owners` | - |
| `sac_column_to_field_id_lookup` | Group Company ID mapping | `sac_column_name`, `field_id` | - | - |

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

- **Purpose**: Drop temp objects from a prior migration in
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

- **Purpose**: MLC Company ID mapping: mlc_company
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

- **Purpose**: Group Company ID mapping
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
| 1 | legacy_identifier, legacy_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details_vct'::VARCHAR(100), COALESCE(s.legacy_identifier::text, s.legacy_id::text), ... |
| 2 | legacy_name, legacy_imo_number, legacy_vessel_category_id, legacy_vessel_sub_category_id, legacy_vessel_code, legacy_vessel_code_existing, legacy_official_number, legacy_call_sign, legacy_mmsi, legacy_flag_id, legacy_port_id, legacy_takeover_date, legacy_vessel_class_id, legacy_ecdis_type_id, legacy_me_make_id, legacy_me_model_id, legacy_me_mcr_kw, legacy_me_is_electronic_engine, legacy_dual_fuelship, legacy_register_owner_id, legacy_bare_boat_owner_id, legacy_mlc_company_id, legacy_ship_management_company_id, legacy_union_code, legacy_service_type, legacy_group_company_id, legacy_owner_id, legacy_advance_joiners_date, legacy_dtw, legacy_dead_weight, legacy_grt, legacy_gross_ton, legacy_ice_class, legacy_polar_code_applicable, legacy_class_no, legacy_group_company_code, legacy_ship_management_company_other, legacy_ship_management_company_address, legacy_mlc_company_other, legacy_mlc_company_address, legacy_manning_management_company, legacy_manning_management_company_other, legacy_manning_management_company_address, legacy_recruitment_company, legacy_recruitment_company_1, legacy_recruitment_company_2, legacy_recruitment_company_3, legacy_owner_other, legacy_owner_address, legacy_register_owner_other, legacy_register_owner_address, legacy_beneficiary_owner_id, legacy_bare_boat_owner_other, legacy_bare_boat_owner_address, legacy_ship_builder, legacy_yard_country_id, legacy_built_year, legacy_build_date, legacy_keel_laid, legacy_launched, legacy_delivered, legacy_handover_date, legacy_hull_number, legacy_vdr_make_id, legacy_cba_code_temp, legacy_vessel_group, legacy_sap_vessel_company_code, legacy_inactive_at, legacy_approval_level, legacy_ot_approval_remarks, legacy_ot_approved_by, legacy_ot_approved_by_name, legacy_ot_reason_for_rejection, legacy_ot_rejected_by, legacy_ot_rejected_by_name, legacy_approval_remarks, legacy_approved_by, legacy_approved_by_name, legacy_reason_for_rejection, legacy_rejected_by, legacy_rejected_by_name, legacy_sma_signing_entity_id, legacy_sma_signing_entity_name, legacy_sma_signing_entity_address, legacy_cba_display, legacy_cba_itf_type | - | field_json | - | ( SELECT COALESCE( jsonb_agg( CASE WHEN field_values_ordered.sac_column_name = 'service_type' AND field_value IS NOT NULL AND field_value::text ~ '^\[.*\]$' THEN jsonb_build_obj... | ( SELECT COALESCE( jsonb_agg( CASE WHEN field_values_ordered.sac_column_name = 'service_type' AND field_value IS NOT NULL AND field_value::text ~ '^\[.*\]$' THEN jsonb_build_obj... |
| 3 | legacy_requester_id | - | requester_id | - | s.legacy_requester_id AS requester_id | s.legacy_requester_id |
| 4 | legacy_reporting_officer_id | - | reporting_officer_id | - | s.legacy_reporting_officer_id AS reporting_officer_id | s.legacy_reporting_officer_id |
| 5 | legacy_remarks | - | remarks | - | TRIM(COALESCE(s.legacy_remarks, '')) AS remarks | TRIM(COALESCE(s.legacy_remarks, '')) |
| 6 | legacy_deleted_at, legacy_ot_rejected_by, legacy_rejected_by, legacy_ot_approved_by, legacy_approved_by | - | vct_status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_ot_rejected_by IS NOT NULL OR s.legacy_rejected_by IS NOT NULL THEN 3 WHEN s.legacy_ot_approved_by IS NOT NULL AND... | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_ot_rejected_by IS NOT NULL OR s.legacy_rejected_by IS NOT NULL THEN 3 WHEN s.legacy_ot_approved_by IS NOT NULL AND... |
| 7 | derived | - | vessel_id | - | vct_vessel_map.new_vessel_id AS vessel_id | vct_vessel_map.new_vessel_id |
| 8 | derived | - | vessel_revision_id | - | vr_map.new_revision_id AS vessel_revision_id | vr_map.new_revision_id |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 11 | derived | - | level | - | NULL AS level | NULL |
| 12 | derived | - | version | - | 1 AS version | 1 |
| 13 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 14 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 15 | legacy_deleted_at, legacy_status | - | status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(s.legacy_status)) = 'ACTIVE' OR TRIM(s.legacy_status) = '0' THEN 0 WHEN UPPE... | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 WHEN s.legacy_status IS NULL THEN 0 WHEN UPPER(TRIM(s.legacy_status)) = 'ACTIVE' OR TRIM(s.legacy_status) = '0' THEN 0 WHEN UPPE... |
| 16 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 17 | legacy_updated_at, legacy_created_at | - | updated_at | - | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) |
| 18 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 19 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 20 | legacy_audit_info, legacy_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN s.legacy_audit_info IS NOT NULL AND s.legacy_audit_info->>'created_by' IS NOT NULL AND s.legacy_audit_info->>'created_by' <> '' THEN s.lega... |
| 21 | derived | - | tags | - | NULL AS tags | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
**Purpose**: Drop temp objects from a prior migration in
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
**Purpose**: MLC Company ID mapping: mlc_company
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
**Purpose**: Group Company ID mapping
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
