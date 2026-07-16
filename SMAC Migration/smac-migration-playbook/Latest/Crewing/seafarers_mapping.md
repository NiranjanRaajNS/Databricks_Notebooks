# Table Mapping: seafarers → seafarers / seafarer_profile / seafarer_service_records

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarers
- **New Database**: smac_crewing_migration
- **New Schema**: public, shore
- **New Tables**: seafarers, seafarer_profile, seafarer_service_records
- **Source Script**: `04-migration-scripts/crewing/seafarers_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarers`
- **New Paths**:
  - `smac_crewing_migration.public.seafarers`
  - `smac_crewing_migration.public.seafarer_profile`
  - `smac_crewing_migration.shore.seafarer_service_records`

## Business Key

- **Business Key**: `cdc_number`
- **Source (orchestration)**: User Profiles (Seafarer) (`user_profiles` → `seafarers`)

## Migration Notes

- Single SAC table `seafarers` split across three SMAC tables: `seafarers`, `seafarer_profile`, `seafarer_service_records`
- SAC `uuid` preserved as SMAC `seafarers.id` when valid; `DISTINCT ON` deduplicates by UUID
- `phone`/`email` initially NULL on INSERT; post-migration UPDATE from `contact_details` (`contact_type = 1`)
- `primary_address`/`alternative_address` initially `{}`; post-migration UPDATE from `contact_details` (`contact_type = 1` / `0`)
- `profile_state_id` derived from SAC `state` with special cases (sign_off → AVAILABLE, travel_planning + signed departure → TRAVELLING)
- Sea experience lookups: `recent_sign_on_date`, `recent_off_date`, `last_doc_company_id` from `sea_experiences`
- `vessel_contracts` filter: only contracts in `relief_summary` (for related migrations); service records use additional SAC columns
- Pre-migration duplicate UUID check on SAC `uuid` column
- Filter: at least `first_name` or `last_name` required

## Special Considerations

- Script uses CASCADE truncate on related tables; `seafarer_service_records` INSERT skipped if table does not exist
- Post-migration identity_profile_id CDC match is commented out in script; set from SAC `identity_user_id` at INSERT
- Orchestration dependencies: `genders`, `nationalities`, `ranks`, `positions`, `vessels`, `companies`, `profile_states`, `availability_remarks`, `agents`, `joining_places`, `working_gear`, `user_profiles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 30

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `gender_id_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `marital_status_id_mapping` | FK lookup | `marital_status_name`, `target_id` | - | `smac_master_migration` |
| `religion_id_mapping` | Store in sessi | `source_id`, `target_id` | - | `synergy_master` |
| `nationality_id_mapping` | FK lookup | `source_id`, `target_id` | - | `synergy_master` |
| `state_id_mapping` | Create lookup ta | `source_id`, `target_id`, `state_name` | - | `synergy_master` |
| `rank_id_mapping` | FK lookup | `source_id`, `target_id` | - | `synergy_master` |
| `rank_uuid_mapping` | FK lookup | `source_uuid`, `target_id` | - | `smac_master_migration` |
| `vessel_category_id_mapping` | Create marital_status lookup mapping by name (source table has 'marital_status' te | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_category_uuid_mapping` | FK lookup | `source_uuid`, `target_id` | - | `smac_master_migration` |
| `vessel_category_name_mapping` | Create religion lookup mapping by ID | `normalized_name`, `category_uuid` | - | `smac_master_migration` |
| `position_id_mapping` | FK lookup | `source_id`, `target_id` | - | `synergy_master` |
| `profile_state_id_mapping` | Create nationality lookup mapping by ID (source table has 'nationality_i | `state_code`, `state_name`, `state_description`, `target_id`, `ps.seafarer_type_id` | - | `smac_master_migration` |
| `profile_status_id_mapping` | Create state lookup mapping by ID (source table has 'state_id' bigint column) | `status_code`, `target_id` | - | `smac_master_migration` |
| `company_id_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `english_language_lookup` | FK lookup | `english_language_id` | - | `smac_master_migration` |
| `language_proficiency_name_mapping` | Create rank UUID lookup mapping (for proposed_rank_id which i | `proficiency_name`, `proficiency_id` | - | `smac_master_migration` |
| `agent_id_mapping` | FK lookup | `source_id`, `target_id` | - | `synergy_master` |
| `country_id_mapping` | Create vessel_category ID lookup mapping (for experience_summary transformation when source has big | `source_id`, `target_id` | - | `synergy_master` |
| `vessel_uuid_mapping` | FK lookup | `source_id`, `target_id` | - | `synergy_vessel` |
| `availability_remark_id_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `blood_group_id_mapping` | Create vessel_category UUID lookup mapping (for experience_summary transformation when source has UUIDs) | `blood_group_name`, `normalized_name`, `target_id` | - | `smac_master_migration` |
| `joining_place_id_mapping` | Create vessel_category name lookup mapping (for ves | `normalized_name`, `target_id` | - | `smac_master_migration` |
| `latest_sea_experience_sign_on_mapping` | FK lookup | `legacy_seafarer_id`, `latest_from_date`, `legacy_company_id` | - | `synergy_seafarer` |
| `latest_doc_company_id_mapping` | Create profile_state lookup mapping by description, code, and name (source tabl | `lses.legacy_seafarer_id`, `new_company_id` | - | - |
| `latest_sea_experience_sign_off_date_mapping` | Create profile_state lookup mapping by description, code, and name (source table has 'state' text column) | `legacy_seafarer_id`, `latest_to_date` | - | `synergy_seafarer` |
| `company_source_to_name_mapping` | FK lookup | `DISTINCT cm.source_id`, `company_name` | - | `smac_master_migration` |
| `seafarer_departures_lookup` | Create profile_status lookup mapping by code (source table has 'is_active' boolean column) | `seafarer_id`, `status_normalized` | - | `synergy_manning` |
| `seafarer_source_id_mapping` | FK lookup | `target_id`, `source_name`, `normalized_name` | - | `smac_master_migration` |
| `local_seafarer_source_lookup` | Create English language lookup (for language_pr | `local_source_id` | - | `smac_master_migration` |
| `boiler_suit_working_gear_lookup` | FK lookup | `working_gear_id`, `wg.sizable` | - | `smac_master_migration` |

### `gender_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### `marital_status_id_mapping`

- **Output columns**: marital_status_name, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE marital_status_id_mapping AS
SELECT
    ms.name as marital_status_name,
    ms.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.marital_statuses WHERE name IS NOT NULL'
) AS ms(id uuid, name text)
WHERE ms.name IS NOT NULL;
```

### `religion_id_mapping`

- **Purpose**: Store in sessi
- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE religion_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.religions'
) AS t(id bigint, identifier uuid);
```

### `nationality_id_mapping`

- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.nationalities'
) AS t(id bigint, uuid uuid);
```

### `state_id_mapping`

- **Purpose**: Create lookup ta
- **Output columns**: source_id, target_id, state_name
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id, name as state_name
FROM dblink('synergy_master',
    'SELECT id, identifier, name FROM public.states'
) AS t(id bigint, identifier uuid, name text);
```

### `rank_id_mapping`

- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS t(id bigint, identifier uuid);
```

### `rank_uuid_mapping`

- **Output columns**: source_uuid, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_uuid_mapping AS
SELECT id as source_uuid, id as target_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.ranks'
) AS t(id uuid);
```

### `vessel_category_id_mapping`

- **Purpose**: Create marital_status lookup mapping by name (source table has 'marital_status' te
- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND target_schema = ''vessel'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### `vessel_category_uuid_mapping`

- **Output columns**: source_uuid, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_uuid_mapping AS
SELECT id as source_uuid, id as target_id
FROM dblink('smac_master_migration',
    'SELECT id FROM vessel.categories'
) AS t(id uuid);
```

### `vessel_category_name_mapping`

- **Purpose**: Create religion lookup mapping by ID
- **Output columns**: normalized_name, category_uuid
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_name_mapping AS
SELECT
    UPPER(TRIM(name)) as normalized_name,
    id as category_uuid
FROM dblink('smac_master_migration',
    'SELECT name, id FROM vessel.categories WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS t(name text, id uuid);
```

### `position_id_mapping`

- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions'
) AS t(id bigint, identifier uuid);
```

### `profile_state_id_mapping`

- **Purpose**: Create nationality lookup mapping by ID (source table has 'nationality_i
- **Output columns**: state_code, state_name, state_description, target_id, ps.seafarer_type_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_state_id_mapping AS
SELECT
    ps.code as state_code,
    ps.name as state_name,
    ps.description as state_description,
    ps.id as target_id,
    ps.seafarer_type_id
FROM dblink('smac_master_migration',
    'SELECT id, code, name, description, seafarer_type_id FROM crewing.profile_states'
) AS ps(id uuid, code text, name text, description text, seafarer_type_id uuid)
WHERE ps.code IS NOT NULL OR ps.name IS NOT NULL OR ps.description IS NOT NULL;
```

### `profile_status_id_mapping`

- **Purpose**: Create state lookup mapping by ID (source table has 'state_id' bigint column)
- **Output columns**: status_code, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_status_id_mapping AS
SELECT
    sps.code as status_code,
    sps.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.seafarer_profile_statuses WHERE code IN (''ACTIVE'', ''INACTIVE'')'
) AS sps(id uuid, code text)
WHERE sps.code IS NOT NULL;
```

### `company_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND target_schema = ''public'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### `english_language_lookup`

- **Output columns**: english_language_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE english_language_lookup AS
SELECT id as english_language_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.languages WHERE UPPER(TRIM(code)) = ''EN'' OR UPPER(TRIM(name)) = ''ENGLISH'' LIMIT 1'
) AS lang(id uuid);
```

### `language_proficiency_name_mapping`

- **Purpose**: Create rank UUID lookup mapping (for proposed_rank_id which i
- **Output columns**: proficiency_name, proficiency_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE language_proficiency_name_mapping AS
SELECT
    lp.name as proficiency_name,
    lp.id as proficiency_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.language_proficiencies WHERE name IS NOT NULL'
) AS lp(id uuid, name text)
WHERE lp.name IS NOT NULL;
```

### `agent_id_mapping`

- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.agents'
) AS t(id bigint, uuid uuid);
```

### `country_id_mapping`

- **Purpose**: Create vessel_category ID lookup mapping (for experience_summary transformation when source has big
- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries'
) AS t(id bigint, uuid uuid);
```

### `vessel_uuid_mapping`

- **Output columns**: source_id, target_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_vessel',
    'SELECT id, uuid FROM public.vessels'
) AS t(id bigint, uuid uuid);
```

### `availability_remark_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE availability_remark_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''availability_remarks'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### `blood_group_id_mapping`

- **Purpose**: Create vessel_category UUID lookup mapping (for experience_summary transformation when source has UUIDs)
- **Output columns**: blood_group_name, normalized_name, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE blood_group_id_mapping AS
SELECT
    bg.name as blood_group_name,
    UPPER(REPLACE(TRIM(bg.name), ' ', '')) as normalized_name,
    bg.id as target_id
FROM dblink('smac_master_migration', 'SELECT id, name FROM public.bloodgroups WHERE name IS NOT NULL') AS bg(id uuid, name text)
WHERE bg.name IS NOT NULL;
```

### `joining_place_id_mapping`

- **Purpose**: Create vessel_category name lookup mapping (for ves
- **Output columns**: normalized_name, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(jp.name)))
    UPPER(TRIM(jp.name)) as normalized_name,
    jp.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.joining_places WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS jp(id uuid, name text)
WHERE jp.name IS NOT NULL
ORDER BY UPPER(TRIM(jp.name)), jp.id;
```

### `latest_sea_experience_sign_on_mapping`

- **Output columns**: legacy_seafarer_id, latest_from_date, legacy_company_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE latest_sea_experience_sign_on_mapping AS
SELECT DISTINCT ON (se.seafarer_id)
    se.seafarer_id AS legacy_seafarer_id,
    se.from_date AS latest_from_date,
    se.ship_management_company_id AS legacy_company_id
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, from_date, ship_management_company_id, created_at
     FROM public.sea_experiences
     WHERE from_date IS NOT NULL'
) AS se(seafarer_id bigint, from_date date, ship_management_company_id bigint, created_at timestamp)
WHERE se.from_date IS NOT NULL
ORDER BY se.seafarer_id, se.from_date DESC NULLS LAST;
```

### `latest_doc_company_id_mapping`

- **Purpose**: Create profile_state lookup mapping by description, code, and name (source tabl
- **Output columns**: lses.legacy_seafarer_id, new_company_id

```sql
CREATE TEMP TABLE latest_doc_company_id_mapping AS
SELECT
    lses.legacy_seafarer_id,
    company_map.target_id AS new_company_id
FROM latest_sea_experience_sign_on_mapping lses
LEFT JOIN company_id_mapping company_map ON company_map.source_id = lses.legacy_company_id;
```

### `latest_sea_experience_sign_off_date_mapping`

- **Purpose**: Create profile_state lookup mapping by description, code, and name (source table has 'state' text column)
- **Output columns**: legacy_seafarer_id, latest_to_date
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE latest_sea_experience_sign_off_date_mapping AS
SELECT DISTINCT ON (se.seafarer_id)
    se.seafarer_id AS legacy_seafarer_id,
    se.to_date AS latest_to_date
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, to_date, created_at, from_date
     FROM public.sea_experiences
     WHERE to_date IS NOT NULL'
) AS se(seafarer_id bigint, to_date date, created_at timestamp, from_date date)
WHERE se.to_date IS NOT NULL
ORDER BY se.seafarer_id, se.from_date DESC NULLS LAST;
```

### `company_source_to_name_mapping`

- **Output columns**: DISTINCT cm.source_id, company_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_source_to_name_mapping AS
SELECT DISTINCT
    cm.source_id,
    COALESCE(TRIM(c.name), '') AS company_name
FROM company_id_mapping cm
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.companies'
) AS c(id uuid, name text)
ON c.id = cm.target_id;
```

### `seafarer_departures_lookup`

- **Purpose**: Create profile_status lookup mapping by code (source table has 'is_active' boolean column)
- **Output columns**: seafarer_id, status_normalized
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_departures_lookup AS
SELECT DISTINCT ON (sd.seafarer_id)
    sd.seafarer_id::bigint as seafarer_id,
    UPPER(TRIM(COALESCE(sd.status, ''))) as status_normalized
FROM dblink('synergy_manning',
    'SELECT seafarer_id, status, COALESCE(updated_at, created_at, NOW()) as last_modified
     FROM public.seafarer_departures
     WHERE status IS NOT NULL
       AND UPPER(TRIM(status)) = ''SIGNED'''
) AS sd(seafarer_id bigint, status text, last_modified timestamp)
WHERE UPPER(TRIM(COALESCE(sd.status, ''))) = 'SIGNED'
ORDER BY sd.seafarer_id, sd.last_modified DESC;
```

### `seafarer_source_id_mapping`

- **Output columns**: target_id, source_name, normalized_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_source_id_mapping AS
SELECT
    ss.id as target_id,
    ss.name as source_name,

    UPPER(REPLACE(REPLACE(TRIM(ss.name), ' ', ''), '_', '')) as normalized_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_source WHERE name IS NOT NULL'
) AS ss(id uuid, name text)
WHERE ss.name IS NOT NULL;
```

### `local_seafarer_source_lookup`

- **Purpose**: Create English language lookup (for language_pr
- **Output columns**: local_source_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE local_seafarer_source_lookup AS
SELECT
    ss.id as local_source_id
FROM dblink('smac_master_migration',
    'SELECT id FROM crewing.seafarer_source WHERE UPPER(TRIM(code)) = ''LOCAL'' LIMIT 1'
) AS ss(id uuid);
```

### `boiler_suit_working_gear_lookup`

- **Output columns**: working_gear_id, wg.sizable
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE boiler_suit_working_gear_lookup AS
SELECT
    wg.id as working_gear_id,
    wg.sizable
FROM dblink('smac_master_migration',
    'SELECT id, sizable FROM crewing.working_gear WHERE name = ''Boiler Suit'' AND deleted_at IS NULL LIMIT 1'
) AS wg(id uuid, sizable boolean);
```

## Column Mapping

Source: `synergy_seafarer.public.seafarers` (single SAC table distributed across three SMAC targets).

### `public.seafarers`

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | text, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` when valid | `DISTINCT ON` by UUID; idempotent via `id_mappings` |
| 2 | `first_name` | text | `first_name` | character varying(100) | `UPPER(LEFT(TRIM(first_name), 100))` | NOT NULL with `last_name` (at least one name required) |
| 3 | `middle_name` | text | `middle_name` | character varying(100) | `UPPER(LEFT(TRIM(middle_name), 100))` | Direct copy with uppercase |
| 4 | `last_name`, `first_name` | text | `last_name` | character varying(100) | `UPPER(COALESCE(TRIM(last_name), last word of first_name, first_name))` | NOT NULL; fallback from `first_name` |
| 5 | `date_of_birth` | date | `date_of_birth` | date | Direct copy | From `seafarers` |
| 6 | `gender` | integer | `gender_id` | uuid | Map via `gender_id_mapping` | Lookup: `migration.table_mappings` (`genders`) |
| 7 | `nationality_id` | bigint | `nationality_id` | uuid | Map via `nationality_id_mapping` | Lookup: `synergy_master.nationalities` |
| 8 | `state_id` | bigint | `state_id` | uuid | Map via `state_id_mapping` | Residential state; lookup: `synergy_master.states` |
| 9 | `contact_details.phone` | text | `phone` | text | INSERT: NULL; post-UPDATE: `TRIM(phone)` from `contact_details` where `contact_type = 1` | See Post-Migration Updates section |
| 10 | `contact_details.email` | text | `email` | text | INSERT: NULL; post-UPDATE: `TRIM(email)` from `contact_details` where `contact_type = 1` | See Post-Migration Updates section |
| 11 | `crew_code` | text | `crew_code` | text | `TRIM(crew_code)` | Direct copy |
| 12 | `old_crew_code` | text | `old_crew_code` | text | `TRIM(old_crew_code)` | Direct copy |
| 13 | `rank_id` | bigint | `rank_id` | uuid | Map via `rank_id_mapping` | Lookup: `synergy_master.ranks` |
| 14 | `last_sailed_position_id` | bigint | `position_id` | uuid | Map via `position_id_mapping` | SAC column renamed to `position_id` |
| 15 | `state` | text | `profile_state_id` | uuid | Map via `profile_state_id_mapping`; sign_off → AVAILABLE; travel_planning + signed departure → TRAVELLING | NOT NULL; empty GUID fallback |
| 16 | `is_active` | boolean | `profile_status_id` | uuid | `true` → ACTIVE; `false` → INACTIVE via `profile_status_id_mapping` | NOT NULL; empty GUID fallback |
| 17 | `cdc_issue_country_id` | bigint | `country_id` | uuid | Map via `country_id_mapping` | CDC issuing country |
| 18 | `availability_remark_id` | bigint | `availability_remark_id` | uuid | Map via `availability_remark_id_mapping` | Lookup: `availability_remarks` |
| 19 | `agent_id` | bigint | `manning_agent_id` | uuid | Map via `agent_id_mapping` | SAC `agent_id` renamed to `manning_agent_id` |
| 20 | `availability_date` | timestamp without time zone | `availability_date` | timestamp without time zone | Direct copy | From `seafarers` |
| 21 | `is_verified` | boolean | `is_verified` | boolean | `COALESCE(is_verified, false)` | NOT NULL |
| 22 | `incomplete_profile` | boolean | `incomplete_profile` | boolean | `COALESCE(incomplete_profile, false)` | NOT NULL |
| 23 | `is_synergy_cadet` | boolean | `is_inhouse_cadet` | boolean | `COALESCE(is_synergy_cadet, false)` | SAC renamed to `is_inhouse_cadet`; NOT NULL |
| 24 | `cdc_without_code` | text | `cdc_number` | text | `TRIM(cdc_without_code)` | Business key |
| 25 | `image_url` | text | `profile_image_url` | text | `TRIM(image_url)` | SAC `image_url` renamed to `profile_image_url` |
| 26 | `last_sailed_vessel_id` | bigint | `last_vessel_id` | uuid | Map via `vessel_uuid_mapping` | Lookup: `synergy_vessel.vessels` |
| 27 | `external_id` | text | `external_id` | text | `TRIM(external_id)` | Direct copy |
| 28 | `sea_experiences.from_date` | date | `recent_sign_on_date` | date | Latest via `latest_sea_experience_sign_on_mapping` | Derived from `sea_experiences` |
| 29 | `sea_experiences.to_date` | date | `recent_off_date` | date | Latest via `latest_sea_experience_sign_off_date_mapping` | Derived from `sea_experiences` |
| 30 | `verified_on` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | From `seafarers` |
| 31 | `current_company_id` | integer | `present_doc_company_id` | uuid | Map via `company_id_mapping` | Lookup: `companies` |
| 32 | `sea_experiences.ship_management_company_id` | bigint | `last_doc_company_id` | uuid | Latest via `latest_doc_company_id_mapping` | From same sign-on record as `recent_sign_on_date` |
| 33 | `home_company_id` | integer | `recruitment_company_id` | uuid | Map via `company_id_mapping` | SAC `home_company_id` renamed |
| 34 | `applied_for_rank_id` | bigint | `applied_for_rank_id` | uuid | Map via `rank_id_mapping` | Lookup: `ranks` |
| 35 | `state` | text | `engagement_type_id` | uuid | Same resolution as `profile_state_id`; uses `seafarer_type_id` | Derived from profile state |
| 36 | `identity_user_id` | text | `identity_profile_id` | uuid | Sanitize and cast to UUID when valid format; else NULL | Link to IDP user |
| 37 | `origin` | text | `source_id` | uuid | Map via `seafarer_source_id_mapping`; fallback LOCAL source | Normalized name match |
| 38 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | All records migrated |
| 39 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 40 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 41 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 42 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name`, `id` | text | `audit_info` | jsonb | `migration.build_audit_info()`; appends `legacy_id` | Names in `notes` |

### `public.seafarer_profile`

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | One profile row per migrated seafarer |
| 2 | `id` (via `inserted_seafarers`) | bigint | `seafarer_id` | uuid | Join `inserted_seafarers` on legacy `id` | FK to `public.seafarers` |
| 3 | `place_of_birth` | text | `place_of_birth` | text | `TRIM(place_of_birth)` | Direct copy |
| 4 | `religion_id` | bigint | `religion_id` | uuid | Map via `religion_id_mapping` | Lookup: `synergy_master.religions` |
| 5 | `marital_status` | text | `marital_statu_id` | uuid | Match name via `marital_status_id_mapping` | SMAC column name retains typo `marital_statu_id` |
| 6 | `blood_group` | text | `blood_group_id` | uuid | Match normalized name via `blood_group_id_mapping` | Lookup: `smac_master.bloodgroups` |
| 7 | `height` | double precision | `height` | numeric(5,2) | Clamp to range -999.99 to 999.99 | Type conversion with bounds |
| 8 | `weight` | double precision | `weight` | numeric(5,2) | Clamp to range -999.99 to 999.99 | Type conversion with bounds |
| 9 | `anniversary_date` | timestamp without time zone | `anniversary_date` | timestamp without time zone | Direct copy | From `seafarers` |
| 10 | — | — | `sap_bp_number` | character varying(50) | Hardcoded NULL | Not in SAC source |
| 11 | `e_reg_no` | text | `e_reg_no` | text | `TRIM(e_reg_no)` | Direct copy |
| 12 | `sss_no` | text | `sss_no` | text | `TRIM(sss_no)` | Direct copy |
| 13 | `hdmf_no` | text | `hdmf_no` | text | `TRIM(hdmf_no)` | Direct copy |
| 14 | `srn_no` | text | `srn_no` | text | `TRIM(srn_no)` | Direct copy |
| 15 | `hair_color` | text | `hair_color` | text | `TRIM(hair_color)` | Direct copy |
| 16 | `eye_color` | text | `eye_color` | text | `TRIM(eye_color)` | Direct copy |
| 17 | `boiler_suit_size` | text | `working_gear` | jsonb | JSON array with Boiler Suit `working_gear_id`, size, `sizable` flag | Lookup: `crewing.working_gear` |
| 18 | `english_language_proficiency` | jsonb | `language_proficiency` | jsonb | Transform to `[{LanguageId, ReadProficiencyId, SpeakProficiencyId, WriteProficiencyId}]` | Maps read/speak/write via `language_proficiency_name_mapping` |
| 19 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 20 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 21 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 22 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name`, `id` | text | `audit_info` | jsonb | `migration.build_audit_info()`; appends `legacy_id` | Names in `notes` |
| 23 | `contact_details` (`contact_type = 0`) | — | `alternative_address` | jsonb | INSERT: `{}`; post-UPDATE: `address_jsonb` from `contact_details` | See Post-Migration Updates section |
| 24 | `contact_details` (`contact_type = 1`) | — | `primary_address` | jsonb | INSERT: `{}`; post-UPDATE: `address_jsonb` from `contact_details` | See Post-Migration Updates section |
| 25 | `deleted_at`, `is_active` | timestamp, boolean | `status` | text | `deleted_at IS NOT NULL` → Deleted; else map `is_active` to Active/Inactive | Text status enum |
| 26 | — | — | `availability_requested` | boolean | Hardcoded `false` | NOT NULL default |
| 27 | `phil_health_id` | text | `philhealth_id` | text | `TRIM(phil_health_id)` | SAC underscore renamed |
| 28 | — | — | `metadata` | jsonb | Hardcoded `{}` | NOT NULL default |

### `shore.seafarer_service_records`

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | One service record per migrated seafarer |
| 2 | `id` (via `inserted_seafarers`) | bigint | `seafarer_id` | uuid | Join `inserted_seafarers` on legacy `id` | FK to `public.seafarers` |
| 3 | `is_to_be_promoted` | boolean | `is_to_be_promoted` | boolean | `COALESCE(is_to_be_promoted, false)` | NOT NULL |
| 4 | `proposed_rank_id` | text (uuid) | `proposed_rank_id` | uuid | Map via `rank_uuid_mapping` on sanitized UUID | Lookup: `ranks` by UUID |
| 5 | `synergy_joining_date` | timestamp without time zone | `joining_date` | timestamp without time zone | Direct copy | SAC renamed to `joining_date` |
| 6 | `suitability` | text[] | `vessel_suitability` | jsonb | Unnest array; map vessel category IDs/names/UUIDs to JSONB array of category UUIDs | Uses `vessel_category_id_mapping`, `vessel_category_uuid_mapping`, `vessel_category_name_mapping` |
| 7 | `experience_summary` | jsonb | `experience_summary` | jsonb | Transform SAC `{rank, vessel}` arrays to SMAC `{Rank, VesselCategory, LastContractCompany}` with FK lookups | Complex JSONB restructure |
| 8 | `proposed_vessel_id` | bigint | `proposed_vessel_id` | uuid | Map via `vessel_uuid_mapping` | Lookup: `vessels` |
| 9 | `proposed_vessel_category` | text | `proposed_vessel_category` | uuid | Sanitize and cast to UUID when valid; else NULL | Direct UUID when valid format |
| 10 | `last_sailed_vessel_imo` | text | `last_sailed_vessel_imo` | text | `TRIM(last_sailed_vessel_imo)` | Direct copy |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 12 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 13 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 16 | `-` |  | `audit_info` | jsonb | `migration.build_audit_info()`; appends `legacy_id` | Minimal audit fields |
| 17 | `deleted_at`, `is_active` | timestamp, boolean | `status` | text | `deleted_at IS NOT NULL` → Deleted; else map `is_active` to Active/Inactive | Text status enum |
| 18 | `synergy_joining_place` | text | `joining_place_id` | uuid | Match normalized name via `joining_place_id_mapping` | Lookup: `joining_places` |
| 19 | `last_engagement_company_id` | bigint | `last_contract_company_name` | text | Resolve company name via `company_id_mapping` + `companies` dblink | Text name, not UUID |

### Post-Migration Updates (`contact_details`)

Applied after INSERT; source table: `synergy_seafarer.public.contact_details`.

| Target Table | Target Column | Legacy Source | Legacy Type | Transformation | Notes |
|--------------|---------------|---------------|-------------|----------------|-------|
| `public.seafarers` | `phone` | `contact_details.phone` | text | `UPDATE` SET `phone = TRIM(phone)` where `contact_type = 1` | `DISTINCT ON (seafarer_id)`; prefers rows with phone populated |
| `public.seafarers` | `email` | `contact_details.email` | text | `UPDATE` SET `email = TRIM(email)` where `contact_type = 1` | Same join via `inserted_seafarers`; prefers rows with email populated |
| `public.seafarer_profile` | `primary_address` | `contact_details.*` | mixed | `UPDATE` SET `primary_address = address_jsonb` where `contact_type = 1` | JSONB: address, city, stateId, countryId, pinCode, phone, email |
| `public.seafarer_profile` | `alternative_address` | `contact_details.*` | mixed | `UPDATE` SET `alternative_address = address_jsonb` where `contact_type = 0` | Same JSONB structure as primary address |

**`address_jsonb` structure** (built from `contact_details`):

| JSONB Key | Legacy Column | Transformation |
|-----------|---------------|----------------|
| `address` | `address` | `TRIM(address)` |
| `city` | `city` | `TRIM(city)` |
| `stateId` | `state_id` | Map via `state_id_mapping` → text UUID |
| `state` | `state_id` | State name from `state_id_mapping` |
| `countryId` | `country_id` | Map via `country_id_mapping` → text UUID |
| `pinCode` | `pin_code` | `TRIM(pin_code)` |
| `phone` | `phone` | `TRIM(phone)` or empty string |
| `email` | `email` | `TRIM(email)` or empty string |
| `airportId`, `latitude`, `longitude` | — | Hardcoded NULL |

**SAC columns in `seafarers` not migrated:** `identifier`, `status`, `last_source_update_date` — not inserted into any of the three SMAC tables.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `genders`, `nationalities`, `states`, `countries`, `ranks`, `positions`, `vessels`, `companies`
- `profile_states`, `seafarer_profile_statuses`, `availability_remarks`, `agents`, `seafarer_sources`
- `religions`, `marital_statuses`, `bloodgroups`, `working_gear`, `language_proficiencies`
- `vessel_categories`, `joining_places`
- `contact_details` (for post-migration phone/email/address updates)
- `user_profiles` (optional — identity_profile_id from SAC `identity_user_id`)

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Gender ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### 2. Marital Status ID Mapping
**Output columns**: `marital_status_name, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE marital_status_id_mapping AS
SELECT
    ms.name as marital_status_name,
    ms.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.marital_statuses WHERE name IS NOT NULL'
) AS ms(id uuid, name text)
WHERE ms.name IS NOT NULL;
```

### 3. Religion ID Mapping
**Purpose**: Store in sessi
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE religion_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.religions'
) AS t(id bigint, identifier uuid);
```

### 4. Nationality ID Mapping
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.nationalities'
) AS t(id bigint, uuid uuid);
```

### 5. State ID Mapping
**Purpose**: Create lookup ta
**Output columns**: `source_id, target_id, state_name`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id, name as state_name
FROM dblink('synergy_master',
    'SELECT id, identifier, name FROM public.states'
) AS t(id bigint, identifier uuid, name text);
```

### 6. Rank ID Mapping
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks'
) AS t(id bigint, identifier uuid);
```

### 7. Rank Uuid ID Mapping
**Output columns**: `source_uuid, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_uuid_mapping AS
SELECT id as source_uuid, id as target_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.ranks'
) AS t(id uuid);
```

### 8. Vessel Category ID Mapping
**Purpose**: Create marital_status lookup mapping by name (source table has 'marital_status' te
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND target_schema = ''vessel'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### 9. Vessel Category Uuid ID Mapping
**Output columns**: `source_uuid, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_uuid_mapping AS
SELECT id as source_uuid, id as target_id
FROM dblink('smac_master_migration',
    'SELECT id FROM vessel.categories'
) AS t(id uuid);
```

### 10. Vessel Category Name ID Mapping
**Purpose**: Create religion lookup mapping by ID
**Output columns**: `normalized_name, category_uuid`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_name_mapping AS
SELECT
    UPPER(TRIM(name)) as normalized_name,
    id as category_uuid
FROM dblink('smac_master_migration',
    'SELECT name, id FROM vessel.categories WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS t(name text, id uuid);
```

### 11. Position ID Mapping
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint as source_id, identifier as target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions'
) AS t(id bigint, identifier uuid);
```

### 12. Profile State ID Mapping
**Purpose**: Create nationality lookup mapping by ID (source table has 'nationality_i
**Output columns**: `state_code, state_name, state_description, target_id, ps.seafarer_type_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_state_id_mapping AS
SELECT
    ps.code as state_code,
    ps.name as state_name,
    ps.description as state_description,
    ps.id as target_id,
    ps.seafarer_type_id
FROM dblink('smac_master_migration',
    'SELECT id, code, name, description, seafarer_type_id FROM crewing.profile_states'
) AS ps(id uuid, code text, name text, description text, seafarer_type_id uuid)
WHERE ps.code IS NOT NULL OR ps.name IS NOT NULL OR ps.description IS NOT NULL;
```

### 13. Profile Status ID Mapping
**Purpose**: Create state lookup mapping by ID (source table has 'state_id' bigint column)
**Output columns**: `status_code, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_status_id_mapping AS
SELECT
    sps.code as status_code,
    sps.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.seafarer_profile_statuses WHERE code IN (''ACTIVE'', ''INACTIVE'')'
) AS sps(id uuid, code text)
WHERE sps.code IS NOT NULL;
```

### 14. Company ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND target_schema = ''public'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### 15. English Language ID Mapping
**Output columns**: `english_language_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE english_language_lookup AS
SELECT id as english_language_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.languages WHERE UPPER(TRIM(code)) = ''EN'' OR UPPER(TRIM(name)) = ''ENGLISH'' LIMIT 1'
) AS lang(id uuid);
```

### 16. Language Proficiency Name ID Mapping
**Purpose**: Create rank UUID lookup mapping (for proposed_rank_id which i
**Output columns**: `proficiency_name, proficiency_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE language_proficiency_name_mapping AS
SELECT
    lp.name as proficiency_name,
    lp.id as proficiency_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.language_proficiencies WHERE name IS NOT NULL'
) AS lp(id uuid, name text)
WHERE lp.name IS NOT NULL;
```

### 17. Agent ID Mapping
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.agents'
) AS t(id bigint, uuid uuid);
```

### 18. Country ID Mapping
**Purpose**: Create vessel_category ID lookup mapping (for experience_summary transformation when source has big
**Output columns**: `source_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_master',
    'SELECT id, uuid FROM public.countries'
) AS t(id bigint, uuid uuid);
```

### 19. Vessel Uuid ID Mapping
**Output columns**: `source_id, target_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT id::bigint as source_id, uuid as target_id
FROM dblink('synergy_vessel',
    'SELECT id, uuid FROM public.vessels'
) AS t(id bigint, uuid uuid);
```

### 20. Availability Remark ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE availability_remark_id_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''availability_remarks'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

### 21. Blood Group ID Mapping
**Purpose**: Create vessel_category UUID lookup mapping (for experience_summary transformation when source has UUIDs)
**Output columns**: `blood_group_name, normalized_name, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE blood_group_id_mapping AS
SELECT
    bg.name as blood_group_name,
    UPPER(REPLACE(TRIM(bg.name), ' ', '')) as normalized_name,
    bg.id as target_id
FROM dblink('smac_master_migration', 'SELECT id, name FROM public.bloodgroups WHERE name IS NOT NULL') AS bg(id uuid, name text)
WHERE bg.name IS NOT NULL;
```

### 22. Joining Place ID Mapping
**Purpose**: Create vessel_category name lookup mapping (for ves
**Output columns**: `normalized_name, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(jp.name)))
    UPPER(TRIM(jp.name)) as normalized_name,
    jp.id as target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.joining_places WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS jp(id uuid, name text)
WHERE jp.name IS NOT NULL
ORDER BY UPPER(TRIM(jp.name)), jp.id;
```

### 23. Latest Sea Experience Sign On ID Mapping
**Output columns**: `legacy_seafarer_id, latest_from_date, legacy_company_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE latest_sea_experience_sign_on_mapping AS
SELECT DISTINCT ON (se.seafarer_id)
    se.seafarer_id AS legacy_seafarer_id,
    se.from_date AS latest_from_date,
    se.ship_management_company_id AS legacy_company_id
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, from_date, ship_management_company_id, created_at
     FROM public.sea_experiences
     WHERE from_date IS NOT NULL'
) AS se(seafarer_id bigint, from_date date, ship_management_company_id bigint, created_at timestamp)
WHERE se.from_date IS NOT NULL
ORDER BY se.seafarer_id, se.from_date DESC NULLS LAST;
```

### 24. Latest Doc Company ID Mapping
**Purpose**: Create profile_state lookup mapping by description, code, and name (source tabl
**Output columns**: `lses.legacy_seafarer_id, new_company_id`

```sql
CREATE TEMP TABLE latest_doc_company_id_mapping AS
SELECT
    lses.legacy_seafarer_id,
    company_map.target_id AS new_company_id
FROM latest_sea_experience_sign_on_mapping lses
LEFT JOIN company_id_mapping company_map ON company_map.source_id = lses.legacy_company_id;
```

### 25. Latest Sea Experience Sign Off Date ID Mapping
**Purpose**: Create profile_state lookup mapping by description, code, and name (source table has 'state' text column)
**Output columns**: `legacy_seafarer_id, latest_to_date`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE latest_sea_experience_sign_off_date_mapping AS
SELECT DISTINCT ON (se.seafarer_id)
    se.seafarer_id AS legacy_seafarer_id,
    se.to_date AS latest_to_date
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, to_date, created_at, from_date
     FROM public.sea_experiences
     WHERE to_date IS NOT NULL'
) AS se(seafarer_id bigint, to_date date, created_at timestamp, from_date date)
WHERE se.to_date IS NOT NULL
ORDER BY se.seafarer_id, se.from_date DESC NULLS LAST;
```

### 26. Company Source To Name ID Mapping
**Output columns**: `DISTINCT cm.source_id, company_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_source_to_name_mapping AS
SELECT DISTINCT
    cm.source_id,
    COALESCE(TRIM(c.name), '') AS company_name
FROM company_id_mapping cm
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, name FROM public.companies'
) AS c(id uuid, name text)
ON c.id = cm.target_id;
```

### 27. Seafarer Departures ID Mapping
**Purpose**: Create profile_status lookup mapping by code (source table has 'is_active' boolean column)
**Output columns**: `seafarer_id, status_normalized`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_departures_lookup AS
SELECT DISTINCT ON (sd.seafarer_id)
    sd.seafarer_id::bigint as seafarer_id,
    UPPER(TRIM(COALESCE(sd.status, ''))) as status_normalized
FROM dblink('synergy_manning',
    'SELECT seafarer_id, status, COALESCE(updated_at, created_at, NOW()) as last_modified
     FROM public.seafarer_departures
     WHERE status IS NOT NULL
       AND UPPER(TRIM(status)) = ''SIGNED'''
) AS sd(seafarer_id bigint, status text, last_modified timestamp)
WHERE UPPER(TRIM(COALESCE(sd.status, ''))) = 'SIGNED'
ORDER BY sd.seafarer_id, sd.last_modified DESC;
```

### 28. Seafarer Source ID Mapping
**Output columns**: `target_id, source_name, normalized_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_source_id_mapping AS
SELECT
    ss.id as target_id,
    ss.name as source_name,

    UPPER(REPLACE(REPLACE(TRIM(ss.name), ' ', ''), '_', '')) as normalized_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_source WHERE name IS NOT NULL'
) AS ss(id uuid, name text)
WHERE ss.name IS NOT NULL;
```

### 29. Local Seafarer Source ID Mapping
**Purpose**: Create English language lookup (for language_pr
**Output columns**: `local_source_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE local_seafarer_source_lookup AS
SELECT
    ss.id as local_source_id
FROM dblink('smac_master_migration',
    'SELECT id FROM crewing.seafarer_source WHERE UPPER(TRIM(code)) = ''LOCAL'' LIMIT 1'
) AS ss(id uuid);
```

### 30. Boiler Suit Working Gear ID Mapping
**Output columns**: `working_gear_id, wg.sizable`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE boiler_suit_working_gear_lookup AS
SELECT
    wg.id as working_gear_id,
    wg.sizable
FROM dblink('smac_master_migration',
    'SELECT id, sizable FROM crewing.working_gear WHERE name = ''Boiler Suit'' AND deleted_at IS NULL LIMIT 1'
) AS wg(id uuid, sizable boolean);
```

Full migration context: `04-migration-scripts/crewing/seafarers_migration.sql`

## Validation

- Run `05-validation/crewing/seafarers_validation.sql` if available
- Run `06-rollback/crewing/seafarers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
