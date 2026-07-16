# Table Mapping: sea_experiences → seafarer_sea_experiences

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: sea_experiences
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_sea_experiences
- **Source Script**: `04-migration-scripts/crewing/seafarer_sea_experiences_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.sea_experiences`
- **New Path**: `smac_crewing_migration.public.seafarer_sea_experiences`

## Business Key

- **Composite Key**: (`seafarer_id`, `vessel_id`, `sign_on_date`)
- **Source (orchestration)**: Sea Experiences (`sea_experiences` → `seafarer_sea_experiences`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with SAC `uuid` as `p_target_id` (fallback source_id: `id::text`)
- `workflow_status_id` is UUID — mapped from `is_verified` via `workflow_status_lookup` (APPROVED / SUBMITTED)
- Key renames: `from_date` → `sign_on_date`, `to_date` → `sign_off_date`, `experience_in_days` → `duration_days`, `is_synergy_experiance` → `is_inhouse_experience`, `port_of_registery_id` → `port_of_registry_id`
- SAC `vessel_id` references `vessel_details.id` (synergy_vessel), resolved to SMAC `vessel_id` via `vessel_details_mapping` → `vessel_info_mapping`
- All FK bigint columns resolved through `migration.table_mappings` lookup tables (see ID Mappings section)

## Special Considerations

- Includes all 45 fields from Corrected Mapping sheet
- Script performs `TRUNCATE TABLE public.seafarer_sea_experiences` before insert (full table reload).
- Orchestration dependencies: `vessels`, `seafarers`, `ranks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 18

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Always delete existing mappings for fresh run | `legacy_seafarer_id`, `new_seafarer_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_info_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id`, `vessel_sub_category_id`, `vessel_name`, `vessel_imo_number` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_category_id_mapping` | FK lookup | `legacy_category_id`, `new_category_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_sub_category_id_mapping` | FK lookup | `legacy_sub_category_id`, `new_sub_category_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `port_of_registry_id_mapping` | FK lookup | `legacy_port_of_registry_id`, `new_port_of_registry_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `rank_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `positions_id_mapping` | Vessel sub category | `legacy_position_id`, `new_position_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ports_id_mapping` | FK lookup | `legacy_port_id`, `new_port_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `sign_off_reasons_id_mapping` | FK lookup | `legacy_reason_id`, `new_reason_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `contract_agreements_id_mapping` | FK lookup | `legacy_contract_id`, `new_contract_agreement_id` | `migration.table_mappings` (see SQL) | - |
| `engine_makes_id_mapping` | FK lookup | `legacy_make_id`, `new_make_id` | - | `synergy_vessel` |
| `engine_models_id_mapping` | Position ID mapping (from smac_master_migration via dblink) | `legacy_model_id`, `new_model_id` | - | `synergy_vessel` |
| `external_company_id_mapping` | FK lookup | `legacy_external_company_id`, `new_external_company_id`, `external_company_name` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `companies_id_mapping` | FK lookup | `legacy_company_id`, `new_company_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_lookup` | FK lookup | `status_code`, `workflow_status_id` | - | `smac_master_migration` |
| `vessel_details_mapping` | FK lookup | `legacy_vessel_details_id`, `legacy_vessel_id`, `vessel_details_identifier` | - | `synergy_vessel` |
| `active_vessel_revision_id_mapping` | FK lookup | `vdm.legacy_vessel_details_id`, `new_vessel_revision_id`, `flag_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `flag_id_from_port_of_registry_mapping` | FK lookup | `legacy_port_of_registry_id`, `legacy_flag_id`, `new_flag_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |

### `seafarer_id_mapping`

- **Purpose**: Always delete existing mappings for fresh run
- **Output columns**: legacy_seafarer_id, new_seafarer_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_seafarer_id,
    target_id AS new_seafarer_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `vessel_info_mapping`

- **Output columns**: legacy_vessel_id, new_vessel_id, vessel_sub_category_id, vessel_name, vessel_imo_number
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_vessel_id,
    filtered.target_id AS new_vessel_id,
    v_info.sub_category_id AS vessel_sub_category_id,
    v_info.name AS vessel_name,
    v_info.imo_number AS vessel_imo_number
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered
LEFT JOIN dblink('smac_master_migration',
    'SELECT sub_category_id, name, imo_number, id FROM vessel.vessels'
) AS v_info(sub_category_id uuid, name text, imo_number text, id uuid)
    ON v_info.id = filtered.target_id;
```

### `vessel_category_id_mapping`

- **Output columns**: legacy_category_id, new_category_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_category_id,
    filtered.target_id AS new_category_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `vessel_sub_category_id_mapping`

- **Output columns**: legacy_sub_category_id, new_sub_category_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_sub_category_id,
    filtered.target_id AS new_sub_category_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sub_categories'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `port_of_registry_id_mapping`

- **Output columns**: legacy_port_of_registry_id, new_port_of_registry_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_of_registry_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_port_of_registry_id,
    filtered.target_id AS new_port_of_registry_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `rank_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_rank_id,
    filtered.target_id AS new_rank_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `positions_id_mapping`

- **Purpose**: Vessel sub category
- **Output columns**: legacy_position_id, new_position_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_position_id,
    filtered.target_id AS new_position_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `ports_id_mapping`

- **Output columns**: legacy_port_id, new_port_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_port_id,
    filtered.target_id AS new_port_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `sign_off_reasons_id_mapping`

- **Output columns**: legacy_reason_id, new_reason_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_reasons_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_reason_id,
    filtered.target_id AS new_reason_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `contract_agreements_id_mapping`

- **Output columns**: legacy_contract_id, new_contract_agreement_id
- **migration.table_mappings**: target_table=contract_agreements

```sql
CREATE TEMP TABLE contract_agreements_id_mapping AS
SELECT
    source_id::bigint AS legacy_contract_id,
    target_id AS new_contract_agreement_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database();
```

### `engine_makes_id_mapping`

- **Output columns**: legacy_make_id, new_make_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE engine_makes_id_mapping AS
SELECT
    em.id AS legacy_make_id,
    em.identifier AS new_make_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.engine_make WHERE identifier IS NOT NULL'
) AS em(id bigint, identifier uuid);
```

### `engine_models_id_mapping`

- **Purpose**: Position ID mapping (from smac_master_migration via dblink)
- **Output columns**: legacy_model_id, new_model_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE engine_models_id_mapping AS
SELECT
    em.id AS legacy_model_id,
    em.identifier AS new_model_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.engine_model WHERE identifier IS NOT NULL'
) AS em(id bigint, identifier uuid);
```

### `external_company_id_mapping`

- **Output columns**: legacy_external_company_id, new_external_company_id, external_company_name
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE external_company_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_external_company_id,
    filtered.target_id AS new_external_company_id,
    osc.name AS external_company_name
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''other_shipping_companies'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.other_shipping_companies'
) AS osc(id uuid, name text)
    ON osc.id = filtered.target_id;
```

### `companies_id_mapping`

- **Output columns**: legacy_company_id, new_company_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_company_id,
    filtered.target_id AS new_company_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### `workflow_status_lookup`

- **Output columns**: status_code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) as status_code,
    ws.id::uuid as workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code IN (''APPROVED'', ''SUBMITTED'')'
) AS ws(code text, id uuid);
```

### `vessel_details_mapping`

- **Output columns**: legacy_vessel_details_id, legacy_vessel_id, vessel_details_identifier
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id,
    vd.identifier AS vessel_details_identifier
FROM dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id FROM public.vessel_details WHERE id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
INNER JOIN sea_experiences_vessel_ids sev ON sev.vessel_id = vd.id;
```

### `active_vessel_revision_id_mapping`

- **Output columns**: vdm.legacy_vessel_details_id, new_vessel_revision_id, flag_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE active_vessel_revision_id_mapping AS
SELECT
    vdm.legacy_vessel_details_id,
    tm.target_id AS new_vessel_revision_id,
    vr.flag_id AS flag_id
FROM vessel_details_mapping vdm
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessel_revisions'''
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vdm.vessel_details_identifier::text
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, flag_id FROM vessel.vessel_revisions'
) AS vr(id uuid, flag_id uuid)
    ON vr.id = tm.target_id;
```

### `flag_id_from_port_of_registry_mapping`

- **Output columns**: legacy_port_of_registry_id, legacy_flag_id, new_flag_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_from_port_of_registry_mapping AS
SELECT DISTINCT
    por.id::bigint AS legacy_port_of_registry_id,
    por.flag_id::bigint AS legacy_flag_id,

    COALESCE(
        flag_map.target_id,
        flag_identifier.identifier::uuid
    ) AS new_flag_id
FROM dblink('synergy_vessel',
    'SELECT id, flag_id FROM public.port_of_registry WHERE flag_id IS NOT NULL'
) AS por(id bigint, flag_id bigint)
LEFT JOIN dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags WHERE identifier IS NOT NULL'
) AS flag_identifier(id bigint, identifier uuid)
    ON flag_identifier.id = por.flag_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''flags'''
) AS flag_map(source_id text, target_id uuid)
    ON flag_map.source_id = flag_identifier.identifier::text;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `COALESCE(uuid::text, id::text)`; `p_target_id` = `uuid` | Idempotent UUID generation; prefers SAC `uuid`, falls back to bigint `id` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; default `00000000-0000-0000-0000-000000000000` if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarers'` |
| 3 | `from_date` | timestamp without time zone | `sign_on_date` | timestamp without time zone | Direct copy | SAC sign-on date renamed to `sign_on_date` |
| 4 | `to_date` | timestamp without time zone | `sign_off_date` | timestamp without time zone | Direct copy (nullable) | SAC sign-off date renamed to `sign_off_date` |
| 5 | `experience_in_days` | bigint | `duration_days` | integer | Direct copy | Experience duration in days |
| 6 | `vessel_id` | bigint | `vessel_id` | uuid | `vessel_id` → `vessel_details_mapping` → `vessel_info_mapping.new_vessel_id` | SAC `vessel_id` references `vessel_details.id`, not `vessels.id`; lookup via `migration.table_mappings` (`vessels`) + `vessel.vessels` |
| 7 | `vessel_Info` (JSONB), `vessel_id` | jsonb, bigint | `vessel_name` | text | `COALESCE(vim.vessel_name, vessel_Info->>'vessel_name' when is_synergy_experiance = false)` | Prefer mapped vessel name; fallback to JSONB for non-Synergy experiences |
| 8 | `vessel_category_id` | bigint | `vessel_category_id` | uuid | Map via `vessel_category_id_mapping`; default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'categories'` (smac_master_migration) |
| 9 | `vessel_id`, `vessel_Info` (JSONB) | bigint, jsonb | `vessel_sub_category_id` | uuid | `COALESCE(vim.vessel_sub_category_id, vscm.new_sub_category_id)` | Prefer sub-category from `vessel.vessels`; fallback maps `vessel_Info->>'VesselCategoryId'` via `vessel_sub_category_id_mapping` |
| 10 | — | — | `linked_assignment_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 11 | `port_of_registery_id`, `vessel_Info` (JSONB) | bigint, jsonb | `port_of_registry_id` | uuid | `COALESCE(porm, porm_fallback, nil UUID)` — fallback from `vessel_Info->>'port_of_registry_id'` when `is_synergy_experiance = false` | SAC column has typo `port_of_registery_id`; lookup: `port_of_registry_id_mapping` → `ports` |
| 12 | `port_of_registery_id`, `vessel_Info` (JSONB) | bigint, jsonb | `flag_id` | uuid | `COALESCE(fprm, fprm_fallback, nil UUID)` via `flag_id_from_port_of_registry_mapping` | Resolves flag through `synergy_vessel.port_of_registry` → `flags` → `migration.table_mappings` (`flags`) |
| 13 | `additional_field` (JSONB) | jsonb | `grt` | numeric(12,2) | Cast `additional_field->>'grt'` to numeric; default `0.0` | Extracted from JSONB; NOT NULL in SMAC |
| 14 | `additional_field` (JSONB) | jsonb | `dwt` | numeric(12,2) | Cast `additional_field->>'dwt'` to numeric when present; else NULL | Extracted from JSONB |
| 15 | `additional_field` (JSONB) | jsonb | `engine_specifications` | jsonb | Restructure `additional_field->'engine_specification'` to PascalCase keys (`DualFuel`, `EngineMakeId`, `EngineModelId`, etc.); map `make_id`/`model_id` via `engine_makes_id_mapping`, `engine_models_id_mapping` | Lookup: `synergy_vessel.engine_make`, `synergy_vessel.engine_model` (identifier preserved as UUID) |
| 16 | `contract_id` | bigint | `contract_agreement_id` | uuid | Map via `contract_agreements_id_mapping` | Lookup: `migration.table_mappings` where `target_table = 'contract_agreements'` |
| 17 | `ship_management_company_id`, `vessel_Info` (JSONB) | bigint, jsonb | `doc_holder_company_id` | uuid | `COALESCE(smcm.new_company_id, vism.new_company_id)` | Direct column preferred; fallback from `vessel_Info->>'ship_management_company_id'`; lookup: `companies_id_mapping` |
| 18 | `external_company_id` | bigint | `external_company_id` | uuid | Map via `external_company_id_mapping` | Lookup: `migration.table_mappings` where `target_table = 'other_shipping_companies'` |
| 19 | `vessel_id` | bigint | `active_vessel_revision_id` | uuid | `vessel_id` → `vessel_details_mapping` → `active_vessel_revision_id_mapping.new_vessel_revision_id` | Maps `vessel_details.identifier` to `vessel_revisions` via `migration.table_mappings` |
| 20 | `rank_id` | bigint | `rank_id` | uuid | Map via `rank_id_mapping`; default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'ranks'` |
| 21 | `position` | bigint | `position_id` | uuid | Map via `positions_id_mapping`; default nil UUID if unmapped | SAC column is `position` (bigint); lookup: `migration.table_mappings` where `target_table = 'positions'` |
| 22 | `active_contract` | boolean | `active_contract` | boolean | `COALESCE(active_contract, false)` | Direct copy with default |
| 23 | `verified_by_name` | character varying | `is_system_generated` | boolean | `true` when `UPPER(TRIM(verified_by_name)) = 'SYSTEM'` | Derived flag; no direct SAC column |
| 24 | `is_synergy_experiance` | boolean | `is_inhouse_experience` | boolean | `COALESCE(is_synergy_experiance, false)` | SAC spelling `is_synergy_experiance` maps to SMAC `is_inhouse_experience` |
| 25 | `from_port_id` | bigint | `sign_on_port_id` | uuid | Map via `ports_id_mapping` (sopim); default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'ports'` |
| 26 | `to_port_id` | bigint | `sign_off_port_id` | uuid | Map via `ports_id_mapping` (soffim); default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'ports'` |
| 27 | `sign_off_reason_id` | bigint | `sign_off_reason_id` | uuid | Map via `sign_off_reasons_id_mapping`; default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'sign_off_reasons'` |
| 28 | — | — | `activities` | jsonb | `NULL` | No equivalent in SAC; not populated |
| 29 | `is_verified` | boolean | `is_verified` | boolean | `COALESCE(is_verified, false)` | Direct copy with default |
| 30 | `verified_on` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | SAC `verified_on` renamed to `verified_at` |
| 31 | `verified_by_id` | text | `verified_by_id` | uuid | Cast to UUID when valid UUID format; else NULL | SAC stores as text; SMAC expects uuid |
| 32 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC; not populated |
| 33 | — | — | `remarks` | text | `NULL` | No equivalent in SAC; not populated |
| 34 | `additional_field` | jsonb | `additional_data` | jsonb | Direct copy of full JSONB | Preserves entire legacy `additional_field` payload |
| 35 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 36 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 37 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 38 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 39 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 40 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — UUID validation for created/updated by; names concatenated into `notes` | Standardized SMAC audit structure; uses `SYSTEM_USER_ID` when source ID is not a valid UUID |
| 41 | `additional_field` (JSONB) | jsonb | `cargo_capacity_info` | jsonb | Extract `additional_field->'cargo_capacity'` | Subset of `additional_field` JSONB |
| 42 | `external_company_id` | bigint | `external_company_name` | text | From `external_company_id_mapping.external_company_name` | Denormalized company name from `other_shipping_companies` |
| 43 | `vessel_id`, `vessel_Info` (JSONB), `ImoNumber` | bigint, jsonb, text | `imo_number` | character varying(50) | `COALESCE(vim.vessel_imo_number, vessel_Info->>'imo_number' when is_synergy_experiance = false)` | Prefer mapped IMO from `vessel.vessels`; fallback to JSONB for non-Synergy experiences |
| 44 | `additional_field` (JSONB) | jsonb | `is_calculated_dwt` | boolean | Cast `additional_field->>'is_calculated_dtw'` to boolean; default `false` | SAC JSONB key has typo `is_calculated_dtw` |
| 45 | `is_verified` | boolean | `workflow_status_id` | uuid | `is_verified = true` → APPROVED status; else SUBMITTED | Lookup: `workflow_status_lookup` from `smac_master_migration.workflow_status` |

**SMAC columns not migrated:** `workflow_instance_id` — no source equivalent in SAC `sea_experiences`.

**SAC columns not migrated:** `sac_contract`, `vessel_snapshot_id`, `verified_by_name` (used only to derive `is_system_generated`).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ranks`
- `seafarers`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Always delete existing mappings for fresh run
**Output columns**: `legacy_seafarer_id, new_seafarer_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_seafarer_id,
    target_id AS new_seafarer_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Vessel Info ID Mapping
**Output columns**: `legacy_vessel_id, new_vessel_id, vessel_sub_category_id, vessel_name, vessel_imo_number`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_vessel_id,
    filtered.target_id AS new_vessel_id,
    v_info.sub_category_id AS vessel_sub_category_id,
    v_info.name AS vessel_name,
    v_info.imo_number AS vessel_imo_number
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered
LEFT JOIN dblink('smac_master_migration',
    'SELECT sub_category_id, name, imo_number, id FROM vessel.vessels'
) AS v_info(sub_category_id uuid, name text, imo_number text, id uuid)
    ON v_info.id = filtered.target_id;
```

### 3. Vessel Category ID Mapping
**Output columns**: `legacy_category_id, new_category_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_category_id,
    filtered.target_id AS new_category_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 4. Vessel Sub Category ID Mapping
**Output columns**: `legacy_sub_category_id, new_sub_category_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_sub_category_id,
    filtered.target_id AS new_sub_category_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sub_categories'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 5. Port Of Registry ID Mapping
**Output columns**: `legacy_port_of_registry_id, new_port_of_registry_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE port_of_registry_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_port_of_registry_id,
    filtered.target_id AS new_port_of_registry_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 6. Rank ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_rank_id,
    filtered.target_id AS new_rank_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 7. Positions ID Mapping
**Purpose**: Vessel sub category
**Output columns**: `legacy_position_id, new_position_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_position_id,
    filtered.target_id AS new_position_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 8. Ports ID Mapping
**Output columns**: `legacy_port_id, new_port_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_port_id,
    filtered.target_id AS new_port_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 9. Sign Off Reasons ID Mapping
**Output columns**: `legacy_reason_id, new_reason_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_reasons_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_reason_id,
    filtered.target_id AS new_reason_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 10. Contract Agreements ID Mapping
**Output columns**: `legacy_contract_id, new_contract_agreement_id`
**migration.table_mappings**: `target_table='contract_agreements'`

```sql
CREATE TEMP TABLE contract_agreements_id_mapping AS
SELECT
    source_id::bigint AS legacy_contract_id,
    target_id AS new_contract_agreement_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database();
```

### 11. Engine Makes ID Mapping
**Output columns**: `legacy_make_id, new_make_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE engine_makes_id_mapping AS
SELECT
    em.id AS legacy_make_id,
    em.identifier AS new_make_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.engine_make WHERE identifier IS NOT NULL'
) AS em(id bigint, identifier uuid);
```

### 12. Engine Models ID Mapping
**Purpose**: Position ID mapping (from smac_master_migration via dblink)
**Output columns**: `legacy_model_id, new_model_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE engine_models_id_mapping AS
SELECT
    em.id AS legacy_model_id,
    em.identifier AS new_model_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.engine_model WHERE identifier IS NOT NULL'
) AS em(id bigint, identifier uuid);
```

### 13. External Company ID Mapping
**Output columns**: `legacy_external_company_id, new_external_company_id, external_company_name`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE external_company_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_external_company_id,
    filtered.target_id AS new_external_company_id,
    osc.name AS external_company_name
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''other_shipping_companies'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.other_shipping_companies'
) AS osc(id uuid, name text)
    ON osc.id = filtered.target_id;
```

### 14. Companies ID Mapping
**Output columns**: `legacy_company_id, new_company_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    filtered.source_id::bigint AS legacy_company_id,
    filtered.target_id AS new_company_id
FROM (
    SELECT source_id, target_id
    FROM dblink('smac_master_migration',
        'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'''
    ) AS t(source_id text, target_id uuid)
    WHERE source_id ~ '^[0-9]+$'
) AS filtered;
```

### 15. Workflow Status ID Mapping
**Output columns**: `status_code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) as status_code,
    ws.id::uuid as workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code IN (''APPROVED'', ''SUBMITTED'')'
) AS ws(code text, id uuid);
```

### 16. Vessel Details ID Mapping
**Output columns**: `legacy_vessel_details_id, legacy_vessel_id, vessel_details_identifier`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id,
    vd.identifier AS vessel_details_identifier
FROM dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id FROM public.vessel_details WHERE id IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
INNER JOIN sea_experiences_vessel_ids sev ON sev.vessel_id = vd.id;
```

### 17. Active Vessel Revision ID Mapping
**Output columns**: `vdm.legacy_vessel_details_id, new_vessel_revision_id, flag_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE active_vessel_revision_id_mapping AS
SELECT
    vdm.legacy_vessel_details_id,
    tm.target_id AS new_vessel_revision_id,
    vr.flag_id AS flag_id
FROM vessel_details_mapping vdm
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessel_revisions'''
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vdm.vessel_details_identifier::text
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, flag_id FROM vessel.vessel_revisions'
) AS vr(id uuid, flag_id uuid)
    ON vr.id = tm.target_id;
```

### 18. Flag Id From Port Of Registry ID Mapping
**Output columns**: `legacy_port_of_registry_id, legacy_flag_id, new_flag_id`
**migration.table_mappings**: see SQL below
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_from_port_of_registry_mapping AS
SELECT DISTINCT
    por.id::bigint AS legacy_port_of_registry_id,
    por.flag_id::bigint AS legacy_flag_id,

    COALESCE(
        flag_map.target_id,
        flag_identifier.identifier::uuid
    ) AS new_flag_id
FROM dblink('synergy_vessel',
    'SELECT id, flag_id FROM public.port_of_registry WHERE flag_id IS NOT NULL'
) AS por(id bigint, flag_id bigint)
LEFT JOIN dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags WHERE identifier IS NOT NULL'
) AS flag_identifier(id bigint, identifier uuid)
    ON flag_identifier.id = por.flag_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''flags'''
) AS flag_map(source_id text, target_id uuid)
    ON flag_map.source_id = flag_identifier.identifier::text;
```

Full migration context: `04-migration-scripts/crewing/seafarer_sea_experiences_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_sea_experiences_validation.sql` if available
- Run `06-rollback/crewing/seafarer_sea_experiences_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
