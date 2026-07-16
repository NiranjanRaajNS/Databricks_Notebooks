# Table Mapping: seafarer_experience → seafarer_special_experiences

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_experience
- **New Database**: smac_master_migration
- **New Schema**: shore
- **New Table**: seafarer_special_experiences
- **Source Script**: `04-migration-scripts/crewing/seafarer_special_experiences_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_experience`
- **New Path**: `smac_master_migration.shore.seafarer_special_experiences`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Special Experiences (`seafarer_experience` → `seafarer_special_experiences`)

## Migration Notes

- Preserves legacy UUID from source id column
- Migrates seafarer_experience to seafarer_special_experiences table. Preserves legacy UUID from source id column. Maps seafarer_id (bigint) to uuid via migration.table_mappings from smac_crewing_migration. Maps vessel_id, vessel_category_id, vessel_sub_type_id, country_id (bigint) to uuid via migration.table_mappings from smac_master_migration. Maps special_experience_type (uuid) directly to experience_type_id. Extracts vessel_name from vessel_info JSONB. Converts vessel_imo from bigint to varchar. Converts from_date/to_date from timestamp to date. Maps is_synergy_experiance to inhouse_experience. Sets status based on deleted_at (3 if deleted, 0 if active). Uses standardized SMAC audit_info structure. Requires seafarers (from smac_crewing_migration), vessels, countries, categories, sub_categories (from smac_master_migration), and special_experience_types tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_special_experiences` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `countries`, `categories`, `sub_categories`, `special_experience_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 11

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | Check if any map | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_category_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_sub_category_id_mapping` | FK lookup | `legacy_vessel_id`, `new_id` | - | `smac_master_migration` |
| `country_id_mapping` | Migrate dat | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `special_experience_category_id_mapping` | Seafarers lookup - query from same database but different schema | `experience_type_code`, `experience_category_id` | - | `smac_master_migration` |
| `special_experience_types_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_lookup` | FK lookup | `status_code`, `workflow_status_id` | - | `smac_master_migration` |
| `companies_id_mapping` | FK lookup | `legacy_company_id`, `new_company_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `designation_id_mapping` | FK lookup | `designation_name_upper`, `designation_id` | - | `smac_master_migration` |
| `vessel_revision_id_mapping` | Create vessel_sub_category_id looku | `legacy_vessel_id`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarers_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessel_id_mapping`

- **Purpose**: Check if any map
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_category_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `vessel_sub_category_id_mapping`

- **Output columns**: legacy_vessel_id, new_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    vm.legacy_id as legacy_vessel_id,
    v.sub_category_id as new_id
FROM vessel_id_mapping vm
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, sub_category_id FROM vessel.vessels WHERE sub_category_id IS NOT NULL'
) AS v(id uuid, sub_category_id uuid)
    ON v.id = vm.new_id;
```

### `country_id_mapping`

- **Purpose**: Migrate dat
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''countries'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `special_experience_category_id_mapping`

- **Purpose**: Seafarers lookup - query from same database but different schema
- **Output columns**: experience_type_code, experience_category_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE special_experience_category_id_mapping AS
SELECT
    TRIM(UPPER(sec.code))::text as experience_type_code,
    sec.id::uuid as experience_category_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM crewing.special_experience_category'
) AS sec(code text, id uuid);
```

### `special_experience_types_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE special_experience_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''special_experience_types'''
) AS t(source_id text, target_id uuid);
```

### `workflow_status_lookup`

- **Output columns**: status_code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::text as status_code,
    ws.id::uuid as workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code IN (''APPROVED'', ''SUBMITTED'')'
) AS ws(code text, id uuid);
```

### `companies_id_mapping`

- **Output columns**: legacy_company_id, new_company_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    t.source_id::bigint as legacy_company_id,
    t.target_id::uuid as new_company_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `designation_id_mapping`

- **Output columns**: designation_name_upper, designation_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE designation_id_mapping AS
SELECT
    TRIM(UPPER(d.name))::text as designation_name_upper,
    d.id::uuid as designation_id
FROM dblink('smac_master_migration',
    'SELECT name, id FROM public.designations WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS d(name text, id uuid);
```

### `vessel_revision_id_mapping`

- **Purpose**: Create vessel_sub_category_id looku
- **Output columns**: legacy_vessel_id, new_vessel_revision_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT
    t.source_id::bigint as legacy_vessel_id,
    t.target_id::uuid as new_vessel_revision_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessel_revisions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_experience'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCH... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | - | - | experience_category_id | - | COALESCE(experience_category_map.experience_category_id, NULL::uuid) AS experience_category_id | COALESCE(experience_category_map.experience_category_id, NULL::uuid) |
| 4 | - | - | experience_type_id | - | COALESCE(experience_type_map.new_id, NULL::uuid) AS experience_type_id | COALESCE(experience_type_map.new_id, NULL::uuid) |
| 5 | - | - | vessel_id | - | COALESCE(vessel_map.new_id, NULL::uuid) AS vessel_id | COALESCE(vessel_map.new_id, NULL::uuid) |
| 6 | vessel_info | - | vessel_name | - | CASE WHEN legacy_data.vessel_info IS NOT NULL AND legacy_data.vessel_info->>'vessel_name' IS NOT NULL THEN legacy_data.vessel_info->>'vessel_name' ELSE NULL END AS vessel_name | CASE WHEN legacy_data.vessel_info IS NOT NULL AND legacy_data.vessel_info->>'vessel_name' IS NOT NULL THEN legacy_data.vessel_info->>'vessel_name' ELSE NULL END |
| 7 | - | - | vessel_category_id | - | COALESCE(vessel_category_map.new_id, NULL::uuid) AS vessel_category_id | COALESCE(vessel_category_map.new_id, NULL::uuid) |
| 8 | - | - | vessel_type_id | - | NULL | NULL::uuid |
| 9 | - | - | vessel_sub_type_id | - | COALESCE(vessel_sub_category_map.new_id, NULL::uuid) AS vessel_sub_type_id | COALESCE(vessel_sub_category_map.new_id, NULL::uuid) |
| 10 | vessel_imo | - | vessel_imo | - | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::varchar, 10) ELSE NULL END AS vessel_imo | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::varchar, 10) ELSE NULL END |
| 11 | - | - | doc_mlc_company_id | - | COALESCE(company_map.new_company_id, NULL::uuid) AS doc_mlc_company_id | COALESCE(company_map.new_company_id, NULL::uuid) |
| 12 | - | - | country_id | - | COALESCE(country_map.new_id, NULL::uuid) AS country_id | COALESCE(country_map.new_id, NULL::uuid) |
| 13 | city | - | city | - | CASE WHEN legacy_data.city IS NOT NULL THEN LEFT(TRIM(legacy_data.city), 100) ELSE NULL END AS city | CASE WHEN legacy_data.city IS NOT NULL THEN LEFT(TRIM(legacy_data.city), 100) ELSE NULL END |
| 14 | - | - | organization_id | - | NULL | NULL::uuid |
| 15 | - | - | organization_name | - | NULL | NULL::varchar |
| 16 | - | - | department | - | NULL | NULL::varchar |
| 17 | - | - | designation_id | - | COALESCE(designation_map.designation_id, NULL::uuid) AS designation_id | COALESCE(designation_map.designation_id, NULL::uuid) |
| 18 | designation | - | designation_name | - | CASE WHEN legacy_data.designation IS NOT NULL THEN LEFT(TRIM(legacy_data.designation), 100) ELSE NULL END AS designation_name | CASE WHEN legacy_data.designation IS NOT NULL THEN LEFT(TRIM(legacy_data.designation), 100) ELSE NULL END |
| 19 | is_synergy_experiance | - | inhouse_experience | - | COALESCE(legacy_data.is_synergy_experiance, false) AS inhouse_experience | COALESCE(legacy_data.is_synergy_experiance, false) |
| 20 | from_date | - | start_date | - | COALESCE(legacy_data.from_date::date, CURRENT_DATE) AS start_date | COALESCE(legacy_data.from_date::date, CURRENT_DATE) |
| 21 | to_date | - | end_date | - | legacy_data.to_date::date AS end_date | legacy_data.to_date::date |
| 22 | to_date | - | duration_days | - | CASE WHEN legacy_data.to_date IS NOT NULL AND legacy_data. | CASE WHEN legacy_data.to_date IS NOT NULL AND legacy_data. |
| 23 | - | - | is_current | - | See source script | See source script |
| 24 | - | - | source | - | See source script | See source script |
| 25 | - | - | external_organization_ref | - | See source script | See source script |
| 26 | - | - | reference_entity | - | See source script | See source script |
| 27 | - | - | reference_id | - | See source script | See source script |
| 28 | - | - | remarks | - | See source script | See source script |
| 29 | - | - | supporting_data | - | See source script | See source script |
| 30 | - | - | workflow_status_id | - | See source script | See source script |
| 31 | - | - | is_verified | - | See source script | See source script |
| 32 | - | - | verified_at | - | See source script | See source script |
| 33 | - | - | verified_by_id | - | See source script | See source script |
| 34 | - | - | verification_notes | - | See source script | See source script |
| 35 | - | - | status | - | See source script | See source script |
| 36 | - | - | tenant_id | - | See source script | See source script |
| 37 | - | - | created_at | - | See source script | See source script |
| 38 | - | - | updated_at | - | See source script | See source script |
| 39 | - | - | archived_at | - | See source script | See source script |
| 40 | - | - | deleted_at | - | See source script | See source script |
| 41 | - | - | audit_info | - | See source script | See source script |
| 42 | - | - | vessel_revision_id | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Vessel ID Mapping
**Purpose**: Check if any map
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 3. Vessel Category ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 4. Vessel Sub Category ID Mapping
**Output columns**: `legacy_vessel_id, new_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_sub_category_id_mapping AS
SELECT
    vm.legacy_id as legacy_vessel_id,
    v.sub_category_id as new_id
FROM vessel_id_mapping vm
LEFT JOIN dblink('smac_master_migration',
    'SELECT id, sub_category_id FROM vessel.vessels WHERE sub_category_id IS NOT NULL'
) AS v(id uuid, sub_category_id uuid)
    ON v.id = vm.new_id;
```

### 5. Country ID Mapping
**Purpose**: Migrate dat
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''countries'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 6. Special Experience Category ID Mapping
**Purpose**: Seafarers lookup - query from same database but different schema
**Output columns**: `experience_type_code, experience_category_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE special_experience_category_id_mapping AS
SELECT
    TRIM(UPPER(sec.code))::text as experience_type_code,
    sec.id::uuid as experience_category_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM crewing.special_experience_category'
) AS sec(code text, id uuid);
```

### 7. Special Experience Types ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE special_experience_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id::uuid as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''special_experience_types'''
) AS t(source_id text, target_id uuid);
```

### 8. Workflow Status ID Mapping
**Output columns**: `status_code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::text as status_code,
    ws.id::uuid as workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code IN (''APPROVED'', ''SUBMITTED'')'
) AS ws(code text, id uuid);
```

### 9. Companies ID Mapping
**Output columns**: `legacy_company_id, new_company_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE companies_id_mapping AS
SELECT
    t.source_id::bigint as legacy_company_id,
    t.target_id::uuid as new_company_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 10. Designation ID Mapping
**Output columns**: `designation_name_upper, designation_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE designation_id_mapping AS
SELECT
    TRIM(UPPER(d.name))::text as designation_name_upper,
    d.id::uuid as designation_id
FROM dblink('smac_master_migration',
    'SELECT name, id FROM public.designations WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS d(name text, id uuid);
```

### 11. Vessel Revision ID Mapping
**Purpose**: Create vessel_sub_category_id looku
**Output columns**: `legacy_vessel_id, new_vessel_revision_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT
    t.source_id::bigint as legacy_vessel_id,
    t.target_id::uuid as new_vessel_revision_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessel_revisions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_special_experiences_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_special_experiences_validation.sql` if available
- Run `06-rollback/crewing/seafarer_special_experiences_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
