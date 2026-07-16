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

- Source table id is bigint, target table id is uuid - generate new UUIDs
- workflow_status_id is UUID (requires workflow status mapping if needed)
- Migrates sea_experiences to seafarer_sea_experiences. Generates new UUIDs for id column (source id is bigint, target id is uuid). Column mappings: from_date → sign_on_date, to_date → sign_off_date, experience_in_days → duration_days. Vessel_id mapping: select id AS vessel_legacy_id from vessels where id in (select vessel_id from public.sea_experiences), then select new_id from migration.table_mappings where legacy_id = vessel_legacy_id. Vessel_name uses same logic to get vessel name. Maps all foreign key references (vessel_id, seafarer_id, rank_id) through migration.table_mappings.

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
| 1 | uuid, id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.uuid, legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'sea_experiences'::VARCHAR(100), COALESCE(l... |
| 2 | derived | - | seafarer_id | - | COALESCE(sim.new_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(sim.new_seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | sign_on_date | - | legacy_data. | legacy_data. |
| 4 | - | - | sign_off_date | - | See source script | See source script |
| 5 | - | - | duration_days | - | See source script | See source script |
| 6 | - | - | vessel_id | - | See source script | See source script |
| 7 | - | - | vessel_name | - | See source script | See source script |
| 8 | - | - | vessel_category_id | - | See source script | See source script |
| 9 | - | - | vessel_sub_category_id | - | See source script | See source script |
| 10 | - | - | linked_assignment_id | - | See source script | See source script |
| 11 | - | - | port_of_registry_id | - | See source script | See source script |
| 12 | - | - | flag_id | - | See source script | See source script |
| 13 | - | - | grt | - | See source script | See source script |
| 14 | - | - | dwt | - | See source script | See source script |
| 15 | - | - | engine_specifications | - | See source script | See source script |
| 16 | - | - | contract_agreement_id | - | See source script | See source script |
| 17 | - | - | doc_holder_company_id | - | See source script | See source script |
| 18 | - | - | external_company_id | - | See source script | See source script |
| 19 | - | - | active_vessel_revision_id | - | See source script | See source script |
| 20 | - | - | rank_id | - | See source script | See source script |
| 21 | - | - | position_id | - | See source script | See source script |
| 22 | - | - | active_contract | - | See source script | See source script |
| 23 | - | - | is_system_generated | - | See source script | See source script |
| 24 | - | - | is_inhouse_experience | - | See source script | See source script |
| 25 | - | - | sign_on_port_id | - | See source script | See source script |
| 26 | - | - | sign_off_port_id | - | See source script | See source script |
| 27 | - | - | sign_off_reason_id | - | See source script | See source script |
| 28 | - | - | activities | - | See source script | See source script |
| 29 | - | - | is_verified | - | See source script | See source script |
| 30 | - | - | verified_at | - | See source script | See source script |
| 31 | - | - | verified_by_id | - | See source script | See source script |
| 32 | - | - | verification_notes | - | See source script | See source script |
| 33 | - | - | remarks | - | See source script | See source script |
| 34 | - | - | additional_data | - | See source script | See source script |
| 35 | - | - | tenant_id | - | See source script | See source script |
| 36 | - | - | created_at | - | See source script | See source script |
| 37 | - | - | updated_at | - | See source script | See source script |
| 38 | - | - | archived_at | - | See source script | See source script |
| 39 | - | - | deleted_at | - | See source script | See source script |
| 40 | - | - | audit_info | - | See source script | See source script |
| 41 | - | - | cargo_capacity_info | - | See source script | See source script |
| 42 | - | - | external_company_name | - | See source script | See source script |
| 43 | - | - | imo_number | - | See source script | See source script |
| 44 | - | - | is_calculated_dwt | - | See source script | See source script |
| 45 | - | - | workflow_status_id | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
