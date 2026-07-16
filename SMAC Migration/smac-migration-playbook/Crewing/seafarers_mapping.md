# Table Mapping: seafarers → seafarers

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarers
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarers
- **Source Script**: `04-migration-scripts/crewing/seafarers_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarers`
- **New Path**: `smac_crewing_migration.public.seafarers`

## Business Key

- **Business Key**: `cdc_number`
- **Source (orchestration)**: User Profiles (Seafarer) (`user_profiles` → `seafarers`)

## Migration Notes

- Using CASCADE to handle foreign key dependencies (e.g., seafarer_temperature_logs, seafarer_bank_accounts, etc.)
- contract_verification_tokens and seafarer_temperature_logs may not exist in the target database
- Updates seafarers.identity_profile_id in smac_crewing database by matching cdc_number with user_profiles.cdc_number from smac_idp_qa_int_v7 database. Requires user_profiles (seafarer) to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_profile` before insert (full table reload).
- Orchestration dependencies: `user_profiles`

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
| `latest_sea_experience_sign_on_mapping` | FK lookup | `legacy_seafarer_id`, `se.` | - | `synergy_seafarer` |
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

- **Output columns**: legacy_seafarer_id, se.
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

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | uuid, id | - | id | - | DISTINCT ON ( COALESCE( CASE WHEN legacy_data.uuid IS NOT NULL AND UPPER(regexp_replace(legacy_data.uuid, '\s+', '', 'g')) ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0... | DISTINCT ON ( COALESCE( CASE WHEN legacy_data.uuid IS NOT NULL AND UPPER(regexp_replace(legacy_data.uuid, '\s+', '', 'g')) ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0... |
| 2 | derived | - | first_name | - | UPPER(LEFT(TRIM(first_name), 100)) as first_name | UPPER(LEFT(TRIM(first_name), 100)) |
| 3 | derived | - | middle_name | - | UPPER(LEFT(TRIM(middle_name), 100)) as middle_name | UPPER(LEFT(TRIM(middle_name), 100)) |
| 4 | derived | - | last_name | - | UPPER(COALESCE( LEFT(TRIM(last_name), 100), CASE WHEN first_name IS NOT NULL AND position(' ' in TRIM(first_name)) > 0 THEN LEFT(TRIM(SPLIT_PART(TRIM(first_name), ' ', -1)), 100... | UPPER(COALESCE( LEFT(TRIM(last_name), 100), CASE WHEN first_name IS NOT NULL AND position(' ' in TRIM(first_name)) > 0 THEN LEFT(TRIM(SPLIT_PART(TRIM(first_name), ' ', -1)), 100... |
| 5 | derived | - | date_of_birth | - | date_of_birth | date_of_birth |
| 6 | derived | - | gender_id | - | gender_map.target_id as gender_id | gender_map.target_id |
| 7 | derived | - | nationality_id | - | nationality_map.target_id as nationality_id | nationality_map.target_id |
| 8 | derived | - | state_id | - | state_map.target_id as state_id | state_map.target_id |
| 9 | derived | - | phone | - | NULL as phone | NULL |
| 10 | derived | - | email | - | NULL as email | NULL |
| 11 | derived | - | crew_code | - | TRIM(crew_code) as crew_code | TRIM(crew_code) |
| 12 | old_crew_code | - | old_crew_code | - | TRIM(legacy_data.old_crew_code) as old_crew_code | TRIM(legacy_data.old_crew_code) |
| 13 | derived | - | rank_id | - | rank_map.target_id as rank_id | rank_map.target_id |
| 14 | derived | - | position_id | - | position_map.target_id as position_id | position_map.target_id |
| 15 | state | - | profile_state_id | - | COALESCE( CASE WHEN UPPER(TRIM(legacy_data.state)) = 'SIGN_OFF' OR UPPER(REPLACE(TRIM(legacy_data.state), '_', '')) = 'SIGNOFF' THEN (SELECT target_id FROM profile_state_id_mapp... | COALESCE( CASE WHEN UPPER(TRIM(legacy_data.state)) = 'SIGN_OFF' OR UPPER(REPLACE(TRIM(legacy_data.state), '_', '')) = 'SIGNOFF' THEN (SELECT target_id FROM profile_state_id_mapp... |
| 16 | is_active | - | profile_status_id | - | COALESCE( CASE WHEN legacy_data.is_active = true THEN (SELECT target_id FROM profile_status_id_mapping WHERE status_code = 'ACTIVE' LIMIT 1) WHEN legacy_data.is_active = false T... | COALESCE( CASE WHEN legacy_data.is_active = true THEN (SELECT target_id FROM profile_status_id_mapping WHERE status_code = 'ACTIVE' LIMIT 1) WHEN legacy_data.is_active = false T... |
| 17 | derived | - | country_id | - | country_map.target_id as country_id | country_map.target_id |
| 18 | derived | - | availability_remark_id | - | availability_remark_map.target_id as availability_remark_id | availability_remark_map.target_id |
| 19 | derived | - | manning_agent_id | - | agent_map.target_id as manning_agent_id | agent_map.target_id |
| 20 | availability_date | - | availability_date | - | legacy_data.availability_date as availability_date | legacy_data.availability_date |
| 21 | is_verified | - | is_verified | - | COALESCE(legacy_data.is_verified, false) as is_verified | COALESCE(legacy_data.is_verified, false) |
| 22 | incomplete_profile | - | incomplete_profile | - | COALESCE(legacy_data.incomplete_profile, false) as incomplete_profile | COALESCE(legacy_data.incomplete_profile, false) |
| 23 | is_synergy_cadet | - | is_inhouse_cadet | - | COALESCE(legacy_data.is_synergy_cadet, false) as is_inhouse_cadet | COALESCE(legacy_data.is_synergy_cadet, false) |
| 24 | cdc_without_code | - | cdc_number | - | TRIM(legacy_data.cdc_without_code) as cdc_number | TRIM(legacy_data.cdc_without_code) |
| 25 | image_url | - | profile_image_url | - | TRIM(legacy_data.image_url) as profile_image_url | TRIM(legacy_data.image_url) |
| 26 | derived | - | last_vessel_id | - | vessel_uuid_map.target_id as last_vessel_id | vessel_uuid_map.target_id |
| 27 | external_id | - | external_id | - | TRIM(legacy_data.external_id) as external_id | TRIM(legacy_data.external_id) |
| 28 | derived | - | recent_sign_on_date | - | latest_sign_on_map.latest_ | latest_sign_on_map.latest_ |
| 29 | - | - | recent_off_date | - | See source script | See source script |
| 30 | - | - | verified_at | - | See source script | See source script |
| 31 | - | - | present_doc_company_id | - | See source script | See source script |
| 32 | - | - | last_doc_company_id | - | See source script | See source script |
| 33 | - | - | recruitment_company_id | - | See source script | See source script |
| 34 | - | - | applied_for_rank_id | - | See source script | See source script |
| 35 | - | - | engagement_type_id | - | See source script | See source script |
| 36 | - | - | identity_profile_id | - | See source script | See source script |
| 37 | - | - | source_id | - | See source script | See source script |
| 38 | - | - | deleted_at | - | See source script | See source script |
| 39 | - | - | tenant_id | - | See source script | See source script |
| 40 | - | - | created_at | - | See source script | See source script |
| 41 | - | - | updated_at | - | See source script | See source script |
| 42 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
**Output columns**: `legacy_seafarer_id, se.`
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
