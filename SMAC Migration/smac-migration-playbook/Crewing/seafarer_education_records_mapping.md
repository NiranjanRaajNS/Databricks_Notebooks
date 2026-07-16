# Table Mapping: education_details → seafarer_education_records

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: education_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_education_records
- **Source Script**: `04-migration-scripts/crewing/seafarer_education_records_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.education_details`
- **New Path**: `smac_crewing_migration.public.seafarer_education_records`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Education Records (`education_details` → `seafarer_education_records`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates education_details to seafarer_education_records table. Preserves legacy identifier UUID when available. Maps seafarer_id (bigint) to uuid via migration.table_mappings. Maps country_id, state_id, and institute_id via migration.table_mappings. Maps institute (text) to institute_id (uuid). Requires seafarers table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_education_records` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `state_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `institution_id_mapping` | FK lookup | `normalized_legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `university_id_mapping` | Create lookup tables | `normalized_university_name`, `university_id` | - | `smac_master_migration` |

### `country_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT legacy_id::bigint as legacy_id, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''countries'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### `state_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT
    id::bigint as legacy_id,
    identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.states WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE identifier IS NOT NULL;
```

### `institution_id_mapping`

- **Output columns**: normalized_legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE institution_id_mapping AS
SELECT
    LOWER(TRIM(LEFT(legacy_id, 100))) AS normalized_legacy_id,
    new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''education_institutes'''
) AS t(legacy_id text, new_id uuid);
```

### `university_id_mapping`

- **Purpose**: Create lookup tables
- **Output columns**: normalized_university_name, university_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE university_id_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_university_name,
    id as university_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.universities WHERE name IS NOT NULL'
) AS u(id uuid, name text)
WHERE name IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'education_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | seafarer_uuid | - | seafarer_id | - | COALESCE( (SELECT id FROM public.seafarers WHERE id = legacy_data.seafarer_uuid LIMIT 1), seafarer_id_mapping.target_id )::uuid as seafarer_id | COALESCE( (SELECT id FROM public.seafarers WHERE id = legacy_data.seafarer_uuid LIMIT 1), seafarer_id_mapping.target_id )::uuid |
| 3 | - | - | education_level_id | - | NULL | NULL::uuid |
| 4 | course_name | - | program_name | - | COALESCE(TRIM(legacy_data.course_name), '') as program_name | COALESCE(TRIM(legacy_data.course_name), '') |
| 5 | - | - | field_of_study_id | - | NULL | NULL::uuid |
| 6 | - | - | specialization | - | NULL | NULL::text |
| 7 | derived | - | institute_id | - | institution_id_mapping.new_id as institute_id | institution_id_mapping.new_id |
| 8 | institute | - | institute_name | - | TRIM(legacy_data.institute) as institute_name | TRIM(legacy_data.institute) |
| 9 | derived | - | university_id | - | university_id_mapping.university_id as university_id | university_id_mapping.university_id |
| 10 | board_or_university | - | university_name | - | TRIM(legacy_data.board_or_university) as university_name | TRIM(legacy_data.board_or_university) |
| 11 | derived | - | country_id | - | country_id_mapping.new_id as country_id | country_id_mapping.new_id |
| 12 | derived | - | state_id | - | state_id_mapping.new_id as state_id | state_id_mapping.new_id |
| 13 | city | - | city | - | TRIM(legacy_data.city) as city | TRIM(legacy_data.city) |
| 14 | - | - | accreditation_body_id | - | NULL | NULL::uuid |
| 15 | - | - | accreditation_code | - | NULL | NULL::text |
| 16 | date_of_joining | - | start_date | - | legacy_data.date_of_joining::date as start_date | legacy_data.date_of_joining::date |
| 17 | date_of_passing | - | end_date | - | legacy_data.date_of_passing::date as end_date | legacy_data.date_of_passing::date |
| 18 | derived | - | is_ongoing | - | false as is_ongoing | false |
| 19 | - | - | study_mode_id | - | NULL | NULL::uuid |
| 20 | - | - | result_system_id | - | NULL | NULL::uuid |
| 21 | - | - | percentage | - | NULL | NULL::numeric(5,2) |
| 22 | - | - | cgpa | - | NULL | NULL::numeric(4,2) |
| 23 | - | - | cgpa_scale | - | NULL | NULL::numeric(4,2) |
| 24 | - | - | grade_id | - | NULL | NULL::uuid |
| 25 | year_of_passing | - | result_year | - | legacy_data.year_of_passing as result_year | legacy_data.year_of_passing |
| 26 | - | - | registration_or_roll_no | - | NULL | NULL::text |
| 27 | - | - | certificate_no | - | NULL | NULL::text |
| 28 | - | - | certificate_issue_date | - | NULL | NULL::date |
| 29 | - | - | certificate_expiry_date | - | NULL | NULL::date |
| 30 | derived | - | document_summary | - | '{}'::jsonb as document_summary | '{}'::jsonb |
| 31 | - | - | program_code | - | NULL | NULL::text |
| 32 | - | - | external_reference | - | NULL | NULL::text |
| 33 | derived | - | tags | - | '{}'::jsonb as tags | '{}'::jsonb |
| 34 | derived | - | workflow_status_id | - | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) as workflow_status_id | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) |
| 35 | derived | - | is_verified | - | false as is_verified | false |
| 36 | - | - | verified_at | - | NULL | NULL::timestamp |
| 37 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 38 | - | - | verification_notes | - | NULL | NULL::text |
| 39 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'deleted'::text ELSE 'active'::text END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'deleted'::text ELSE 'active'::text END |
| 40 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 41 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 42 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 43 | - | - | archived_at | - | NULL | NULL::timestamp |
| 44 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 45 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 46 | grade | - | grade_name | - | TRIM(legacy_data.grade) as grade_name | TRIM(legacy_data.grade) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT legacy_id::bigint as legacy_id, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''countries'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### 2. State ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT
    id::bigint as legacy_id,
    identifier as new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.states WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE identifier IS NOT NULL;
```

### 3. Institution ID Mapping
**Output columns**: `normalized_legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE institution_id_mapping AS
SELECT
    LOWER(TRIM(LEFT(legacy_id, 100))) AS normalized_legacy_id,
    new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''education_institutes'''
) AS t(legacy_id text, new_id uuid);
```

### 4. University ID Mapping
**Purpose**: Create lookup tables
**Output columns**: `normalized_university_name, university_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE university_id_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_university_name,
    id as university_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.universities WHERE name IS NOT NULL'
) AS u(id uuid, name text)
WHERE name IS NOT NULL;
```

Full migration context: `04-migration-scripts/crewing/seafarer_education_records_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_education_records_validation.sql` if available
- Run `06-rollback/crewing/seafarer_education_records_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
