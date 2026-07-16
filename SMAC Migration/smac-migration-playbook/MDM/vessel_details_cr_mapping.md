# Table Mapping: vessel_details_cr → vessel_change_requests

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details_cr
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_change_requests
- **Source Script**: `04-migration-scripts/master/vessel_details_cr_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details_cr`
- **New Path**: `smac_master_migration.vessel.vessel_change_requests`

## Business Key

- **Composite Key**: (`vessel_id`, `current_revision_id`, `initiated_by`)
- **Source (orchestration)**: Vessel Change Requests (`vessel_details_cr` → `vessel_change_requests`)

## Migration Notes

- Preserve legacy identifier (UUID) as new id if available, otherwise generate new UUID
- Record legacy id → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessels and vessel.vessel_revisions to be migrated first (for FK mappings)
- Migrates vessel_details_cr to vessel_change_requests. Preserves identifier UUID as id when available. Maps vessel_id (bigint) to vessel_id (uuid) via migration.table_mappings. Maps vessel_id_new (bigint) to current_revision_id and proposed_revision_id (uuid) via migration.table_mappings. Maps approval_status (text) to cr_status (integer): Draft=0, PendingApproval=1, Approved=2, Rejected=3. Conditionally maps approval_status_changed_by/at to approved_by/at, rejected_by/at, or cancelled_by/at based on approval_status. Stores change_type, change_requested_sections, and other metadata in fields jsonb. Maps status (varchar) to status (integer) with deleted_at precedence. Requires vessels and vessel_revisions tables to be migrated first.

## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Use DISTINCT ON (source_id) to prevent duplicate mappings when multiple staging rows match the same target row
- Script performs `TRUNCATE TABLE vessel.vessel_change_requests` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 21

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_details_cr_to_vessel_mapping` | Drop temp objects from a prior migration in the same psql session (temp tables are s | `legacy_cr_id`, `legacy_imo_number`, `legacy_name`, `new_vessel_id` | - | `synergy_vessel` |
| `vessel_revision_id_mapping` | FK lookup | `legacy_vessel_id_new`, `new_revision_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `flag_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `port_id_mapping` | Create lookup to match vessel_details_cr to vessels by imo_number or name fo | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `class_id_mapping` | FK lookup | `legacy_class_id`, `new_class_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_category_id_mapping` | FK lookup | `source_category_id`, `target_category_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_sub_category_id_mapping` | Vessel Revision ID mapping (vessel_id_new bigint → current_revision_id uuid) | `source_sub_category_id`, `target_sub_category_id` | `migration.table_mappings` (see SQL) | - |
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
| `register_owner_id_mapping` | MLC Company ID mapping: mlc_company_id (bigint) → companies.id (uuid) | `legacy_register_owner_id`, `new_register_owner_id` | `?.?.vessel_registered_owners` → `?.?.owners` | - |
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

### `vessel_details_cr_to_vessel_mapping`

- **Purpose**: Drop temp objects from a prior migration in the same psql session (temp tables are s
- **Output columns**: legacy_cr_id, legacy_imo_number, legacy_name, new_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_cr_to_vessel_mapping AS
SELECT DISTINCT
    vdcr.id::bigint AS legacy_cr_id,
    vdcr.imo_number AS legacy_imo_number,
    vdcr.name AS legacy_name,
    v.id AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, imo_number, name FROM public.vessel_details_cr WHERE imo_number IS NOT NULL OR name IS NOT NULL'
) AS vdcr(id bigint, imo_number text, name text)
LEFT JOIN vessel.vessels v ON
    (vdcr.imo_number IS NOT NULL AND v.imo_number = vdcr.imo_number)
    OR (vdcr.imo_number IS NULL AND vdcr.name IS NOT NULL AND UPPER(TRIM(v.name)) = UPPER(TRIM(vdcr.name)));
```

### `vessel_revision_id_mapping`

- **Output columns**: legacy_vessel_id_new, new_revision_id
- **migration.table_mappings**: target_table=vessel_revisions
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT
    vd.id::bigint AS legacy_vessel_id_new,
    tm.target_id AS new_revision_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_details WHERE id IS NOT NULL'
) AS vd(id bigint, identifier uuid)
JOIN migration.table_mappings tm ON
    tm.target_table = 'vessel_revisions'
    AND tm.target_db = current_database()
    AND (
        (vd.identifier IS NOT NULL AND tm.source_id = vd.identifier::text)
        OR (vd.identifier IS NULL AND tm.source_id = vd.id::text)
    );
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

- **Purpose**: Create lookup to match vessel_details_cr to vessels by imo_number or name fo
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

- **Purpose**: Vessel Revision ID mapping (vessel_id_new bigint → current_revision_id uuid)
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

- **Purpose**: MLC Company ID mapping: mlc_company_id (bigint) → companies.id (uuid)
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
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'main_engine_model'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'electronic_engine'
        WHEN 'DUAL_FUEL' = ANY(fd.tags) THEN 'dual_fuelship'
        WHEN 'REGISTERED_OWNER' = ANY(fd.tags) THEN 'register_owner_id'
        WHEN 'CU...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_identifier | - | id | - | COALESCE(s.legacy_identifier, gen_random_uuid()) AS id | COALESCE(s.legacy_identifier, gen_random_uuid()) |
| 2 | derived | - | vessel_id | - | COALESCE(v_map.new_vessel_id, vcr_vessel_map.new_vessel_id) AS vessel_id | COALESCE(v_map.new_vessel_id, vcr_vessel_map.new_vessel_id) |
| 3 | derived | - | current_revision_id | - | vr_map.new_revision_id AS current_revision_id | vr_map.new_revision_id |
| 4 | derived | - | proposed_revision_id | - | vr_map.new_revision_id AS proposed_revision_id | vr_map.new_revision_id |
| 5 | legacy_change_requested_by | - | initiated_by | - | s.legacy_change_requested_by AS initiated_by | s.legacy_change_requested_by |
| 6 | legacy_approval_status, legacy_approval_status_changed_by | - | approved_by | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_status_changed_by ELSE NULL END AS approved_by | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_status_changed_by ELSE NULL END |
| 7 | legacy_approval_status, legacy_approval_status_changed_at | - | approved_at | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_status_changed_at ELSE NULL END AS approved_at | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_status_changed_at ELSE NULL END |
| 8 | legacy_approval_status, legacy_approval_status_changed_by | - | rejected_by | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_status_changed_by ELSE NULL END AS rejected_by | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_status_changed_by ELSE NULL END |
| 9 | legacy_approval_status, legacy_approval_status_changed_at | - | rejected_at | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_status_changed_at ELSE NULL END AS rejected_at | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_status_changed_at ELSE NULL END |
| 10 | legacy_approval_status, legacy_approval_status_changed_by | - | cancelled_by | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_status_changed_by ELSE NULL END AS cancelled_by | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_status_changed_by ELSE NULL END |
| 11 | legacy_approval_status, legacy_approval_status_changed_at | - | cancelled_at | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_status_changed_at ELSE NULL END AS cancelled_at | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_status_changed_at ELSE NULL END |
| 12 | legacy_approval_status, legacy_approval_comment | - | approval_reason | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_comment ELSE NULL END AS approval_reason | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'APPROVED' THEN s.legacy_approval_comment ELSE NULL END |
| 13 | legacy_approval_status, legacy_approval_comment | - | rejection_reason | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_comment ELSE NULL END AS rejection_reason | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'REJECTED' THEN s.legacy_approval_comment ELSE NULL END |
| 14 | legacy_approval_status, legacy_approval_comment | - | cancellation_reason | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_comment ELSE NULL END AS cancellation_reason | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'CANCELLED' THEN s.legacy_approval_comment ELSE NULL END |
| 15 | sac_column_name, legacy_vessel_id_new, legacy_name, legacy_imo_number, legacy_vessel_category_id, legacy_vessel_sub_category_id, legacy_official_number, legacy_service_type, legacy_ship_builder, legacy_built_year, legacy_launched, legacy_takeover_date, legacy_handover_date, legacy_delivered, legacy_keel_laid, legacy_flag_id, legacy_port_id, legacy_ecdis_type_id, legacy_vdr_make_id, legacy_owner_id, legacy_vessel_code, legacy_p_and_i, legacy_call_sign, legacy_vessel_class_id, legacy_class_no, legacy_ship_management_company_id, legacy_bare_boat_owner_id, legacy_group_company_id, legacy_register_owner_id, legacy_cba_code, legacy_group_company_code, legacy_dual_fuelship, legacy_hull_number, legacy_ice_class, legacy_main_engine_model, legacy_mmsi, legacy_polar_code_applicable, legacy_recruitment_company, legacy_recruitment_company_1, legacy_recruitment_company_2, legacy_recruitment_company_3, legacy_vessel_group, legacy_electronic_engine, legacy_manning_management_company, legacy_beneficiary_owner_id, legacy_build_date, legacy_ecdis_type_id_1, legacy_ecdis_type_id_2, legacy_ecdis_type_id_3, legacy_ecdis_type_id_4, legacy_yard_country_id, legacy_change_type, legacy_change_requested_sections, legacy_change_requested_by_name, legacy_approval_status_changed_by_name, legacy_vessel_version | - | fields | - | COALESCE( ( SELECT COALESCE( jsonb_agg( CASE WHEN field_values.sac_column_name = 'service_type' AND field_value IS NOT NULL AND field_value::text ~ '^\[.*\]$' THEN jsonb_build_o... | COALESCE( ( SELECT COALESCE( jsonb_agg( CASE WHEN field_values.sac_column_name = 'service_type' AND field_value IS NOT NULL AND field_value::text ~ '^\[.*\]$' THEN jsonb_build_o... |
| 16 | legacy_approval_status | - | cr_status | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'DRAFT' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) IN ('PENDING', 'PENDINGAPPROVAL') THEN 1 ... | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) = 'DRAFT' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_approval_status, ''))) IN ('PENDING', 'PENDINGAPPROVAL') THEN 1 ... |
| 17 | legacy_effective_ | - | effective_date | - | CASE WHEN s.legacy_effective_ | CASE WHEN s.legacy_effective_ |
| 18 | - | - | tenant_id | - | See source script | See source script |
| 19 | - | - | parent_id | - | See source script | See source script |
| 20 | - | - | level | - | See source script | See source script |
| 21 | - | - | version | - | See source script | See source script |
| 22 | - | - | defined_by | - | See source script | See source script |
| 23 | - | - | workflow_status | - | See source script | See source script |
| 24 | - | - | status | - | See source script | See source script |
| 25 | - | - | created_at | - | See source script | See source script |
| 26 | - | - | updated_at | - | See source script | See source script |
| 27 | - | - | deleted_at | - | See source script | See source script |
| 28 | - | - | archived_at | - | See source script | See source script |
| 29 | - | - | audit_info | - | See source script | See source script |
| 30 | - | - | tags | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`

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

### 2. Vessel Details Cr To Vessel ID Mapping
**Purpose**: Drop temp objects from a prior migration in the same psql session (temp tables are s
**Output columns**: `legacy_cr_id, legacy_imo_number, legacy_name, new_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_cr_to_vessel_mapping AS
SELECT DISTINCT
    vdcr.id::bigint AS legacy_cr_id,
    vdcr.imo_number AS legacy_imo_number,
    vdcr.name AS legacy_name,
    v.id AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, imo_number, name FROM public.vessel_details_cr WHERE imo_number IS NOT NULL OR name IS NOT NULL'
) AS vdcr(id bigint, imo_number text, name text)
LEFT JOIN vessel.vessels v ON
    (vdcr.imo_number IS NOT NULL AND v.imo_number = vdcr.imo_number)
    OR (vdcr.imo_number IS NULL AND vdcr.name IS NOT NULL AND UPPER(TRIM(v.name)) = UPPER(TRIM(vdcr.name)));
```

### 3. Vessel Revision ID Mapping
**Output columns**: `legacy_vessel_id_new, new_revision_id`
**migration.table_mappings**: `target_table='vessel_revisions'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT
    vd.id::bigint AS legacy_vessel_id_new,
    tm.target_id AS new_revision_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_details WHERE id IS NOT NULL'
) AS vd(id bigint, identifier uuid)
JOIN migration.table_mappings tm ON
    tm.target_table = 'vessel_revisions'
    AND tm.target_db = current_database()
    AND (
        (vd.identifier IS NOT NULL AND tm.source_id = vd.identifier::text)
        OR (vd.identifier IS NULL AND tm.source_id = vd.id::text)
    );
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
**Purpose**: Create lookup to match vessel_details_cr to vessels by imo_number or name fo
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
**Purpose**: Vessel Revision ID mapping (vessel_id_new bigint → current_revision_id uuid)
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
**Purpose**: MLC Company ID mapping: mlc_company_id (bigint) → companies.id (uuid)
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
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'main_engine_model'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'electronic_engine'
        WHEN 'DUAL_FUEL' = ANY(fd.tags) THEN 'dual_fuelship'
        WHEN 'REGISTERED_OWNER' = ANY(fd.tags) THEN 'register_owner_id'
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        WHEN 'MLC_SHIP_OWNER' = ANY(fd.tags) THEN 'mlc_company_id'
        WHEN 'DOC_COMPANY' = ANY(fd.tags) THEN 'ship_management_company_id'
        WHEN 'UNION_TERMS' = ANY(fd.tags) THEN 'cba_code'
        WHEN 'MANAGEMENT_SERVICE_TYPE' = ANY(fd.tags) THEN 'service_type'
        WHEN 'GROUP_OWNER' = ANY(fd.tags) THEN 'group_company_id'
        WHEN 'GROUP_CUSTOMER_GROUP_OWNER_NAME' = ANY(fd.tags) THEN 'owner_id'

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
        WHEN 'MAIN_ENGINE_MAKE' = ANY(fd.tags) THEN 'main_engine_model'
        WHEN 'IS_MAIN_ENGINE_ELECTRONIC' = ANY(fd.tags) THEN 'electronic_engine'
        WHEN 'DUAL_FUEL' = ANY(fd.tags) THEN 'dual_fuelship'
        WHEN 'REGISTERED_OWNER' = ANY(fd.tags) THEN 'register_owner_id'
        WHEN 'CUSTOMER_SIGNING_ENTITY' = ANY(fd.tags) THEN 'bare_boat_owner_id'
        WHEN 'MLC_SHIP_OWNER' = ANY(fd.tags) THEN 'mlc_company_id'
        WHEN 'DOC_COMPANY' = ANY(fd.tags) THEN 'ship_management_company_id'
        WHEN 'UNION_TERMS' = ANY(fd.tags) THEN 'cba_code'
        WHEN 'MANAGEMENT_SERVICE_TYPE' = ANY(fd.tags) THEN 'service_type'
        WHEN 'GROUP_OWNER' = ANY(fd.tags) THEN 'group_company_id'
        WHEN 'GROUP_CUSTOMER_GROUP_OWNER_NAME' = ANY(fd.tags) THEN 'owner_id'
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
      END IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/vessel_details_cr_migration.sql`

## Validation

- Run `05-validation/master/vessel_details_cr_validation.sql` if available
- Run `06-rollback/master/vessel_details_cr_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
