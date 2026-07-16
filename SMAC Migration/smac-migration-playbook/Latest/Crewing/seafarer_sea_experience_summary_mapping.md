# Table Mapping: grouped_sea_experience_summary → seafarer_sea_experience_summary

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: grouped_sea_experience_summary
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_sea_experience_summary
- **Source Script**: `04-migration-scripts/crewing/seafarer_sea_experience_summary_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.grouped_sea_experience_summary`
- **New Path**: `smac_crewing_migration.public.seafarer_sea_experience_summary`

## Business Key

- **Composite Key**: (`seafarer_id`, `tenant_id`)
- **Source (orchestration)**: Seafarer Sea Experience Summary (Merged) (`grouped_sea_experience_summary` → `seafarer_sea_experience_summary`)

## Migration Notes

- Source table `grouped_sea_experience_summary` — composite PK `(seafarer_id, tenant_id)`; no separate `id` column
- `seafarer_id` (bigint) mapped to uuid via `seafarer_id_mapping`; rows without mapping excluded
- `operator_experience` (numeric) → `operator_experience_months_decimal` and summary text (`'X months'`)
- JSONB arrays transformed to SMAC text summaries via helper functions (`transform_rank_experience`, `transform_vessel_category_experience`, `transform_doc_holder_company_experience`)
- `position_experience_summary` hardcoded `'[]'` — source has no `experience_by_position` field
- `last_calculated_date` from `updated_at::date`; `created_at`/`updated_at` from `updated_at` (source has no `created_at`)
- `audit_info` uses `SYSTEM_USER_ID` with provenance note; no SAC user columns
- Run `update_seafarer_sea_experience_summary_operator_experience.sql` post-migration for formatted operator summary

## Special Considerations

- Primary key is composite (seafarer_id, tenant_id) - no separate id column
- Maps seafarer_id via migration.table_mappings from current database (smac_crewing_migration)
- Script performs `TRUNCATE TABLE public.seafarer_sea_experience_summary` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 9

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Check if any mappi | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | - | `synergy_master` |
| `rank_names_lookup` | FK lookup | `rank_id`, `rank_name` | - | `smac_master_migration` |
| `position_id_mapping` | FK lookup | `legacy_position_id`, `new_position_id` | - | `synergy_master` |
| `position_names_lookup` | FK lookup | `position_id`, `position_name` | - | `smac_master_migration` |
| `vessel_category_id_mapping` | FK lookup | `legacy_category_id`, `new_category_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_category_names_lookup` | FK lookup | `category_id`, `category_name` | - | `smac_master_migration` |
| `ship_management_company_id_mapping` | Position ID mapping (from synergy_master.public.positions) | `legacy_company_id`, `new_company_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `company_names_lookup` | FK lookup | `company_id`, `company_name` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Purpose**: Check if any mappi
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `rank_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    id::bigint as legacy_rank_id,
    identifier as new_rank_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE id > 0;
```

### `rank_names_lookup`

- **Output columns**: rank_id, rank_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_names_lookup AS
SELECT
    r.id as rank_id,
    r.name as rank_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks'
) AS r(id uuid, name text);
```

### `position_id_mapping`

- **Output columns**: legacy_position_id, new_position_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT
    id::bigint as legacy_position_id,
    identifier as new_position_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE id > 0;
```

### `position_names_lookup`

- **Output columns**: position_id, position_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE position_names_lookup AS
SELECT
    p.id as position_id,
    p.name as position_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.positions'
) AS p(id uuid, name text);
```

### `vessel_category_id_mapping`

- **Output columns**: legacy_category_id, new_category_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint as legacy_category_id,
    target_id as new_category_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
  AND source_id::bigint > 0;
```

### `vessel_category_names_lookup`

- **Output columns**: category_id, category_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_names_lookup AS
SELECT
    c.id as category_id,
    c.name as category_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.categories'
) AS c(id uuid, name text);
```

### `ship_management_company_id_mapping`

- **Purpose**: Position ID mapping (from synergy_master.public.positions)
- **Output columns**: legacy_company_id, new_company_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ship_management_company_id_mapping AS
SELECT
    source_id::bigint as legacy_company_id,
    target_id as new_company_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
  AND source_id::bigint > 0;
```

### `company_names_lookup`

- **Output columns**: company_id, company_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_names_lookup AS
SELECT
    c.id as company_id,
    c.name as company_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.companies'
) AS c(id uuid, name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping` | Part of composite PK; required mapping |
| 2 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Part of composite PK |
| 3 | `operator_experience` | numeric | `operator_experience_months_decimal` | numeric(10,2) | `COALESCE(operator_experience::numeric(10,2), 0)` | Direct numeric copy |
| 4 | `operator_experience` | numeric | `operator_experience_summary` | text | Append `' months'`; default `'0 months'` | Human-readable summary text |
| 5 | `experience_by_rank` | jsonb | `rank_experience_summary` | text | `pg_temp.transform_rank_experience()` — aggregate by rank, map IDs, convert days to months | Default `'[]'` when NULL |
| 6 | `experience_by_vessel_category` | jsonb | `vessel_category_experience_summary` | text | `pg_temp.transform_vessel_category_experience()` | Default `'[]'` when NULL |
| 7 | `experience_by_ship_management_company` | jsonb | `doc_holder_company_experience_summary` | text | `pg_temp.transform_doc_holder_company_experience()` | Default `'[]'` when NULL |
| 8 | — | — | `position_experience_summary` | text | Hardcoded `'[]'` | No source column; helper available if data added |
| 9 | `operator_experience` | numeric | `sea_going_operator_experience_summary` | text | Same as operator summary or NULL | Reuses operator experience |
| 10 | `updated_at` | timestamp without time zone | `last_calculated_date` | date | `COALESCE(updated_at::date, CURRENT_DATE)` | No dedicated calculation date in SAC |
| 11 | `updated_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Source has no `created_at` |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID, ...)` with migration provenance note | No SAC audit columns |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** None in dblink SELECT. Records with unmapped `seafarer_id` excluded entirely.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Check if any mappi
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Rank ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    id::bigint as legacy_rank_id,
    identifier as new_rank_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE id > 0;
```

### 3. Rank Names ID Mapping
**Output columns**: `rank_id, rank_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_names_lookup AS
SELECT
    r.id as rank_id,
    r.name as rank_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks'
) AS r(id uuid, name text);
```

### 4. Position ID Mapping
**Output columns**: `legacy_position_id, new_position_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT
    id::bigint as legacy_position_id,
    identifier as new_position_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid)
WHERE id > 0;
```

### 5. Position Names ID Mapping
**Output columns**: `position_id, position_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE position_names_lookup AS
SELECT
    p.id as position_id,
    p.name as position_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.positions'
) AS p(id uuid, name text);
```

### 6. Vessel Category ID Mapping
**Output columns**: `legacy_category_id, new_category_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_id_mapping AS
SELECT
    source_id::bigint as legacy_category_id,
    target_id as new_category_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
  AND source_id::bigint > 0;
```

### 7. Vessel Category Names ID Mapping
**Output columns**: `category_id, category_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_category_names_lookup AS
SELECT
    c.id as category_id,
    c.name as category_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM vessel.categories'
) AS c(id uuid, name text);
```

### 8. Ship Management Company ID Mapping
**Purpose**: Position ID mapping (from synergy_master.public.positions)
**Output columns**: `legacy_company_id, new_company_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ship_management_company_id_mapping AS
SELECT
    source_id::bigint as legacy_company_id,
    target_id as new_company_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''companies'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id ~ '^[0-9]+$'
  AND source_id::bigint > 0;
```

### 9. Company Names ID Mapping
**Output columns**: `company_id, company_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_names_lookup AS
SELECT
    c.id as company_id,
    c.name as company_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.companies'
) AS c(id uuid, name text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_sea_experience_summary_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_sea_experience_summary_validation.sql` if available
- Run `06-rollback/crewing/seafarer_sea_experience_summary_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
