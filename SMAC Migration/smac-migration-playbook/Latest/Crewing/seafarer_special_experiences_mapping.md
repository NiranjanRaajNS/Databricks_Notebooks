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

- Source `seafarer_experience` → `shore.seafarer_special_experiences`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- FK lookups: seafarers, vessels, categories, countries, companies, designations, `special_experience_category` (by code), `special_experience_types`, `vessel_revisions`
- `vessel_sub_type_id` derived from vessel → `vessels.sub_category_id` (not from `vessel_sub_category_id` column)
- `duration_days` calculated from `from_date`/`to_date` (not `experience_in_days`)
- `workflow_status_id` from `is_verified` (APPROVED vs SUBMITTED)
- All records migrated including deleted; `status` text from `deleted_at`
- Requires seafarers, vessels, countries, categories, sub_categories, special_experience_types migrated first

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
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC UUID |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID fallback | |
| 3 | `experience_type` | text | `experience_category_id` | uuid | Match `special_experience_category.code` | |
| 4 | `special_experience_type` | text | `experience_type_id` | uuid | Map via `special_experience_types` mappings | |
| 5 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` | |
| 6 | `vessel_info` → `vessel_name` | jsonb | `vessel_name` | text | `vessel_info->>'vessel_name'` | |
| 7 | `vessel_category_id` | bigint | `vessel_category_id` | uuid | Map via `categories` mappings | |
| 8 | — | — | `vessel_type_id` | uuid | `NULL` | Not populated |
| 9 | `vessel_id` | bigint | `vessel_sub_type_id` | uuid | Via vessel → `sub_category_id` | Not from `vessel_sub_category_id` |
| 10 | `vessel_imo` | bigint | `vessel_imo` | character varying(10) | `LEFT(vessel_imo::varchar, 10)` | |
| 11 | `ship_management_company_id` | bigint | `doc_mlc_company_id` | uuid | Map via `companies` mappings | |
| 12 | `country_id` | bigint | `country_id` | uuid | Map via `countries` mappings | |
| 13 | `city` | text | `city` | character varying(100) | `LEFT(TRIM(city), 100)` | |
| 14 | — | — | `organization_id` | uuid | `NULL` | |
| 15 | — | — | `organization_name` | character varying | `NULL` | |
| 16 | — | — | `department` | character varying | `NULL` | |
| 17 | `designation` | text | `designation_id` | uuid | Match `designations.name` | |
| 18 | `designation` | text | `designation_name` | character varying(100) | `LEFT(TRIM(designation), 100)` | |
| 19 | `is_synergy_experiance` | boolean | `inhouse_experience` | boolean | `COALESCE(is_synergy_experiance, false)` | |
| 20 | `from_date` | timestamp without time zone | `start_date` | date | `COALESCE(from_date::date, CURRENT_DATE)` | |
| 21 | `to_date` | timestamp without time zone | `end_date` | date | `to_date::date` | |
| 22 | `from_date`, `to_date` | timestamp without time zone | `duration_days` | integer | Date difference in days | Not `experience_in_days` |
| 23 | — | — | `is_current` | boolean | Hardcoded `false` | |
| 24 | — | — | `source` | character varying | `NULL` | |
| 25 | — | — | `external_organization_ref` | character varying | `NULL` | |
| 26 | — | — | `reference_entity` | character varying | `NULL` | |
| 27 | — | — | `reference_id` | uuid | `NULL` | |
| 28 | `remarks` | text | `remarks` | character varying(1000) | `LEFT(TRIM(remarks), 1000)` | |
| 29 | — | — | `supporting_data` | jsonb | Hardcoded `'{}'` | |
| 30 | `is_verified` | boolean | `workflow_status_id` | uuid | `true` → APPROVED; else SUBMITTED | |
| 31 | `is_verified` | boolean | `is_verified` | boolean | Direct copy | |
| 32 | `verified_at` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | |
| 33 | — | — | `verified_by_id` | uuid | `NULL` | |
| 34 | — | — | `verification_notes` | character varying | `NULL` | |
| 35 | `deleted_at` | timestamp without time zone | `status` | character varying(20) | `'Deleted'` / `'Active'` | |
| 36 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 37 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 38 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 39 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 40 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 41 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` from legacy audit fields | No `legacy_id` |
| 42 | `vessel_id` | bigint | `vessel_revision_id` | uuid | Map via `vessel_revisions` lookup | |

**SMAC columns not migrated:** `vessel_type_id`, `organization_id`, `organization_name`, `department`, `source`, `external_organization_ref`, `reference_entity`, `reference_id`, `verified_by_id`, `verification_notes`, `archived_at` — no SAC equivalent; set NULL or defaults.

**SAC columns not migrated:** `vessel_sub_category_id`, `experience_in_days` — in dblink SELECT but not used (sub-type from vessel; duration from dates).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories`
- `countries`
- `seafarers`
- `special_experience_types`
- `sub_categories`
- `vessels`

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
