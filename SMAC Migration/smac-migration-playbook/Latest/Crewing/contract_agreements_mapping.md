# Table Mapping: contract_agreements → contract_agreements

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_agreements
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: contract_agreements
- **Source Script**: `04-migration-scripts/crewing/contract_agreements_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_agreements`
- **New Path**: `smac_crewing_migration.public.contract_agreements`

## Business Key

- **Business Key**: `vr.vessel_id`
- **Source (orchestration)**: Update Contract Agreements Agreement Group ID (`contract_agreements` → `contract_agreements`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `contract_id` → `seafarer_contracts`; `agreement_group_id` → `contract_agreement_sets` (same legacy row id)
- Vessel/revision resolved same as `contract_agreement_sets` (JSONB + vessel_contracts fallback)
- `wage_info` transformed via `migration.transform_wage_info()` with `wage_components` lookup
- `cba_id` from agreement `cba` code or vessel contract CBA fallback; `proposed_wage` from `vessel_contracts.salary`
- `workflow_status_id` from `workflow_status` master by status code (`InDraft` → `DRAFT`)
- `agreement_status` and `status` mapped from legacy status text; `is_active` complex rule on Signed + EffectiveFrom
- `rpsl_company_id` from `metadata->>'CompanyName'` or `MLCHolder` via companies lookup
- `ON CONFLICT (id) DO UPDATE` for idempotent re-runs
- Requires `seafarer_contracts`, `contract_agreement_sets`, vessels, CBAs, wage_components migrated first

## Special Considerations

- Converts terms from text to jsonb
- Include ALL contract agreements, even if vessel_id is NULL (for proper LEFT JOIN)
- Script performs `TRUNCATE TABLE public.contract_agreements` before insert (full table reload).
- Orchestration dependencies: `contract_agreements`, `contract_agreement_sets`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `contract_agreement_vessel_mapping` | If no mappings found in current database, try via dblink to other databases | `contract_agreement_id`, `legacy_vessel_id` | - | `synergy_manning` |
| `vessel_info_mapping` | FK lookup | `DISTINCT cavm.legacy_vessel_id`, `new_vessel_id` | - | `synergy_vessel` |
| `vessel_revision_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |

### `contract_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `contract_agreement_vessel_mapping`

- **Purpose**: If no mappings found in current database, try via dblink to other databases
- **Output columns**: contract_agreement_id, legacy_vessel_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_agreement_vessel_mapping AS
SELECT DISTINCT
    ca.id AS contract_agreement_id,
    COALESCE(
        CASE
            WHEN ca.vessel_info IS NOT NULL
                 AND ca.vessel_info->>'Id' IS NOT NULL
                 AND (ca.vessel_info->>'Id') ~ '^[0-9]+$'
                 AND (ca.vessel_info->>'Id')::bigint > 0
            THEN (ca.vessel_info->>'Id')::bigint
            ELSE NULL
        END,
        vc.vessel_id
    ) AS legacy_vessel_id
FROM dblink('synergy_manning',
    'SELECT
        id,
        contract_id,
        vessel_info
     FROM public.contract_agreements
     WHERE contract_id IN (
         SELECT id FROM public.vessel_contracts
         WHERE uuid IS NOT NULL
           AND deleted_at IS NULL
     )'
) AS ca(id bigint, contract_id bigint, vessel_info jsonb)
LEFT JOIN dblink('synergy_manning',
    'SELECT
        id AS vessel_contract_id,
        vessel_id
     FROM public.vessel_contracts
     WHERE vessel_id IS NOT NULL'
) AS vc(vessel_contract_id bigint, vessel_id bigint)
    ON vc.vessel_contract_id = ca.contract_id;
```

### `vessel_info_mapping`

- **Output columns**: DISTINCT cavm.legacy_vessel_id, new_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### `vessel_revision_mapping`

- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC UUID; `DISTINCT ON (id)` |
| 2 | `contract_id` | bigint | `contract_id` | uuid | Map via `contract_id_mapping`; default nil UUID | Lookup: `seafarer_contracts` |
| 3 | `id` | bigint | `agreement_group_id` | uuid | Map via `agreement_group_id_mapping` (`contract_agreement_sets`); default nil UUID | Same legacy id → agreement set |
| 4 | `vessel_info`, `contract_id` | jsonb, bigint | `vessel_id` | uuid | Resolve + map via `vessel_info_mapping` | Lookup: `vessels` (dblink) |
| 5 | `vessel_id` (mapped) | uuid | `vessel_revision_id` | uuid | Active revision from `vessel_revision_mapping` | Lookup: `vessel_revisions` |
| 6 | `agreement_no`, `id` | text, bigint | `agreement_no` | text | `COALESCE(NULLIF(TRIM(agreement_no), ''), 'AGREEMENT_' \|\| id::text)` | NOT NULL fallback |
| 7 | `agreement_type` | text | `agreement_type` | text | `TRIM(agreement_type)` | NOT NULL |
| 8 | — | — | `jurisdiction_type` | text | Hardcoded `'NORMAL'` | SMAC default |
| 9 | — | — | `is_mandatory` | boolean | Hardcoded `false` | SMAC default |
| 10 | `start_date` | timestamp | `start_date` | timestamp without time zone | Direct copy | NOT NULL |
| 11 | `end_date` | timestamp | `end_date` | timestamp without time zone | Direct copy | Nullable |
| 12 | `metadata`, `start_date`, `created_at` | jsonb, timestamp | `effective_date` | timestamp without time zone | `EffectiveFrom` → `start_date` → `created_at` → `NOW()` | NOT NULL |
| 13 | `status`, `is_active`, `metadata` | varchar, boolean, jsonb | `is_active` | boolean | true only when Signed + active + EffectiveFrom ≤ today | Complex business rule |
| 14 | — | — | `wage_scale_id` | uuid | `NULL` | No equivalent in SAC |
| 15 | `wages_info` | jsonb | `wage_info` | jsonb | `migration.transform_wage_info()` — component name → `wage_components` lookup | Restructures CBA/company/deduction arrays |
| 16 | `vessel_contracts.salary` | numeric(12,2) | `proposed_wage` | numeric | From `vessel_contract_salary_lookup` by `contract_id` | Joined lookup |
| 17 | `revised_salary_info` | jsonb | `revised_salary` | jsonb | Direct copy | Nullable |
| 18 | — | — | `currency_code` | text | Hardcoded `'USD'` | SMAC default |
| 19 | — | — | `exchange_rate` | numeric | Hardcoded `1` | SMAC default |
| 20 | `terms` | text | `terms` | jsonb | Non-empty text → `jsonb_build_object('text', TRIM(terms))` | Text to JSONB |
| 21 | `cba` | text | `cba_id` | uuid | `cba_code_mapping` by code; fallback `vessel_cba_lookup` | Lookup: `cbas` by code match |
| 22 | `agreement_file_path` | text | `agreement_file_path` | text | `NULLIF(TRIM(agreement_file_path), '')` | Nullable |
| 23 | `is_digitally_signed` | boolean | `is_digitally_signed` | boolean | `COALESCE(is_digitally_signed, false)` | Default false |
| 24 | — | — | `signing_provider` | text | `NULL` | No equivalent in SAC |
| 25 | `metadata` | jsonb | `metadata` | jsonb | Direct copy | Nullable |
| 26 | `status` | character varying | `agreement_status` | text | Map legacy status enum (Approved, Draft, Signed, Void, etc.) | See script CASE mapping |
| 27 | `status` | character varying | `workflow_status_id` | uuid | Map via `workflow_status_lookup` by status code | Lookup: `workflow_status` master |
| 28 | — | — | `is_verified` | boolean | Hardcoded `false` | SMAC default |
| 29 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 30 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC |
| 31 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC |
| 32 | `deleted_at`, `status` | timestamp, varchar | `status` | text | `deleted_at` or Void/Cancelled → `Inactive`; else `Active` | Record lifecycle status |
| 33 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 34 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 35 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | NOT NULL |
| 36 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 37 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 38 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | No `legacy_id` (UUID preserved) |
| 39 | `external_agreement_id` | text | `external_agreement_id` | text | `NULLIF(TRIM(external_agreement_id), '')` | Nullable |
| 40 | `metadata` → CompanyName | jsonb | `rpsl_company_id` | uuid | `company_name_mapping` on CompanyName or MLCHolder | Lookup: `companies` by name |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `position_id`, `task_id`, `place_of_engagement`, `source`, `notes`, `seafarer_info`, `vessel_info`, `family_info`, `poseidon_agreement_file_path`, `poseidon_wages_info` — not in INSERT column list (some used in sibling `contract_agreement_sets` migration).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_agreement_sets`
- `contract_agreements`
- `public.contract_agreement_sets`
- `public.seafarer_contracts`
- `seafarer_contracts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Contract Agreement Vessel ID Mapping
**Purpose**: If no mappings found in current database, try via dblink to other databases
**Output columns**: `contract_agreement_id, legacy_vessel_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_agreement_vessel_mapping AS
SELECT DISTINCT
    ca.id AS contract_agreement_id,
    COALESCE(
        CASE
            WHEN ca.vessel_info IS NOT NULL
                 AND ca.vessel_info->>'Id' IS NOT NULL
                 AND (ca.vessel_info->>'Id') ~ '^[0-9]+$'
                 AND (ca.vessel_info->>'Id')::bigint > 0
            THEN (ca.vessel_info->>'Id')::bigint
            ELSE NULL
        END,
        vc.vessel_id
    ) AS legacy_vessel_id
FROM dblink('synergy_manning',
    'SELECT
        id,
        contract_id,
        vessel_info
     FROM public.contract_agreements
     WHERE contract_id IN (
         SELECT id FROM public.vessel_contracts
         WHERE uuid IS NOT NULL
           AND deleted_at IS NULL
     )'
) AS ca(id bigint, contract_id bigint, vessel_info jsonb)
LEFT JOIN dblink('synergy_manning',
    'SELECT
        id AS vessel_contract_id,
        vessel_id
     FROM public.vessel_contracts
     WHERE vessel_id IS NOT NULL'
) AS vc(vessel_contract_id bigint, vessel_id bigint)
    ON vc.vessel_contract_id = ca.contract_id;
```

### 4. Vessel Info ID Mapping
**Output columns**: `DISTINCT cavm.legacy_vessel_id, new_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_info_mapping AS
SELECT DISTINCT
    cavm.legacy_vessel_id,
    vm.new_id AS new_vessel_id
FROM contract_agreement_vessel_mapping cavm

INNER JOIN dblink('synergy_vessel',
    'SELECT DISTINCT id
     FROM public.vessels
     WHERE id IS NOT NULL'
) AS vd(id bigint) ON vd.id = cavm.legacy_vessel_id

INNER JOIN vessel_id_mapping vm ON vm.legacy_id = cavm.legacy_vessel_id
WHERE cavm.legacy_vessel_id IS NOT NULL
  AND vm.new_id IS NOT NULL;
```

### 5. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, status, created_at
     FROM vessel.vessel_revisions
     WHERE status = 0
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, status integer, created_at timestamp)
INNER JOIN vessel_info_mapping vim ON vim.new_vessel_id = vr.vessel_id
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/crewing/contract_agreements_migration.sql`

## Validation

- Run `05-validation/crewing/contract_agreements_validation.sql` if available
- Run `06-rollback/crewing/contract_agreements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
