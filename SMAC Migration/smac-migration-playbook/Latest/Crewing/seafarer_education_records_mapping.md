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

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `seafarer_id`: direct lookup on `seafarer_uuid` in `public.seafarers`; fallback to `migration.table_mappings` where `target_table = 'seafarers'`
- `institute_id` resolved via `institution_id_mapping` — LOWER(TRIM(LEFT(source_id, 100))) match against `education_institutes` mappings
- `university_id` resolved via `university_id_mapping` — LOWER(TRIM(`board_or_university`)) matched to `public.universities.name`
- `country_id` via `country_id_mapping` (`migration.table_mappings` where `target_table = 'countries'`)
- `state_id` via `state_id_mapping` (SAC `states.identifier` from `synergy_master`)
- `status` derived from `deleted_at` only (Case 1): `deleted_at IS NOT NULL` → `'deleted'`, else `'active'`
- `workflow_status_id` from `approved_workflow_status` lookup (code = APPROVED)
- Uses `migration.build_audit_info()` — source has no audit columns
- Requires `seafarers` table migrated first

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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `seafarer_uuid`, `seafarer_id` | uuid, bigint | `seafarer_id` | uuid | `COALESCE(seafarers.id match on seafarer_uuid, seafarer_id_mapping.target_id)` | Primary: direct UUID; fallback: `table_mappings` where `target_table = 'seafarers'` |
| 3 | — | — | `education_level_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 4 | `course_name` | text | `program_name` | text | `COALESCE(TRIM(course_name), '')` | NOT NULL in SMAC; empty string when NULL |
| 5 | — | — | `field_of_study_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 6 | — | — | `specialization` | text | `NULL` | No equivalent in SAC; not populated |
| 7 | `institute` | text | `institute_id` | uuid | Join `institution_id_mapping` on LOWER(TRIM(LEFT(institute, 100))) | Lookup: `education_institutes` via `table_mappings` (dblink `smac_master_migration`) |
| 8 | `institute` | text | `institute_name` | text | `TRIM(institute)` | Text preserved alongside `institute_id` |
| 9 | `board_or_university` | text | `university_id` | uuid | Join `university_id_mapping` on LOWER(TRIM(board_or_university)) | Lookup: `public.universities` via dblink (`smac_master_migration`) |
| 10 | `board_or_university` | text | `university_name` | text | `TRIM(board_or_university)` | Text preserved alongside `university_id` |
| 11 | `country_id` | bigint | `country_id` | uuid | Map via `country_id_mapping` | Lookup: `table_mappings` where `target_table = 'countries'` |
| 12 | `state_id` | bigint | `state_id` | uuid | Map via `state_id_mapping` | Lookup: SAC `states.identifier` from `synergy_master` |
| 13 | `city` | text | `city` | text | `TRIM(city)` | Direct copy with whitespace trimmed |
| 14 | — | — | `accreditation_body_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 15 | — | — | `accreditation_code` | text | `NULL` | No equivalent in SAC; not populated |
| 16 | `date_of_joining` | timestamp | `start_date` | date | `date_of_joining::date` | Direct date cast |
| 17 | `date_of_passing` | timestamp | `end_date` | date | `date_of_passing::date` | Direct date cast |
| 18 | — | — | `is_ongoing` | boolean | Hardcoded `false` | NOT NULL in SMAC; not in SAC source |
| 19 | — | — | `study_mode_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 20 | — | — | `result_system_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 21 | — | — | `percentage` | numeric(5,2) | `NULL` | No equivalent in SAC; not populated |
| 22 | — | — | `cgpa` | numeric(4,2) | `NULL` | No equivalent in SAC; not populated |
| 23 | — | — | `cgpa_scale` | numeric(4,2) | `NULL` | No equivalent in SAC; not populated |
| 24 | — | — | `grade_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 25 | `year_of_passing` | integer | `result_year` | integer | Direct copy | Nullable |
| 26 | — | — | `registration_or_roll_no` | text | `NULL` | No equivalent in SAC; not populated |
| 27 | — | — | `certificate_no` | text | `NULL` | No equivalent in SAC; not populated |
| 28 | — | — | `certificate_issue_date` | date | `NULL` | No equivalent in SAC; not populated |
| 29 | — | — | `certificate_expiry_date` | date | `NULL` | No equivalent in SAC; not populated |
| 30 | — | — | `document_summary` | jsonb | Hardcoded `'{}'::jsonb` | SMAC default; not in SAC source |
| 31 | — | — | `program_code` | text | `NULL` | No equivalent in SAC; not populated |
| 32 | — | — | `external_reference` | text | `NULL` | No equivalent in SAC; not populated |
| 33 | — | — | `tags` | jsonb | Hardcoded `'{}'::jsonb` | SMAC default; not in SAC source |
| 34 | — | — | `workflow_status_id` | uuid | `(SELECT workflow_status_id FROM approved_workflow_status LIMIT 1)` | APPROVED workflow status lookup |
| 35 | — | — | `is_verified` | boolean | Hardcoded `false` | NOT NULL in SMAC; not in SAC source |
| 36 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 37 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 38 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC; not populated |
| 39 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `'deleted'`; else `'active'` | Case 1 — `deleted_at` only (no SAC `status` column) |
| 40 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 41 | `created_at` | timestamp(6) without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 42 | `updated_at` | timestamp(6) without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 43 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 44 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 45 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Source has no audit columns; `legacy_id` handled by `id_mappings` |
| 46 | `grade` | text | `grade_name` | text | `TRIM(grade)` | SAC `grade` maps to SMAC `grade_name` |

**SMAC columns not migrated:** None beyond defaults — all target columns populated from source or explicit defaults.

**SAC columns not migrated:** `seafarer_id` (bigint) — used only as fallback when `seafarer_uuid` lookup fails.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

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
