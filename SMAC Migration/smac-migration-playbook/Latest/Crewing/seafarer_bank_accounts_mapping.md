# Table Mapping: bank_details → seafarer_bank_accounts

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: bank_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_bank_accounts
- **Source Script**: `04-migration-scripts/crewing/seafarer_bank_accounts_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.bank_details`
- **New Path**: `smac_crewing_migration.public.seafarer_bank_accounts`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Bank Accounts (`bank_details` → `seafarer_bank_accounts`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with SAC `uuid` as `p_target_id` (duplicate UUID check on `uuid` column before migration)
- `seafarer_uuid` (varchar) maps to `seafarer_id` via direct join on `public.seafarers.id`; fallback via `seafarer_id_mapping` (bigint `seafarer_id`); default nil UUID if unmapped
- `family_uuid` maps to `family_member_id` and `beneficiary_type_id` via `seafarer_family_members` and `beneficiary_types` (Mother/Father → Parent)
- `state_id` / `country_id` (bigint) resolved via `states_id_mapping` / `countries_id_mapping` from `smac_master_migration`
- `account_type` (integer) → `account_type_id` via `bank_account_types` mappings; `ifsc_code` used to match `bank_id` / `branch_id` by code
- SAC `status` (varchar) → `workflow_status_id` via `workflow_status.name` match; special: SignOn Pending → Submitted, Request Change → In Review; default Draft
- `deleted_at` drives `status` text (`active` / `deleted`); `deleted_at` preserved
- Uses `migration.build_audit_info()` with created/updated by names in `notes`; `legacy_id` handled by `id_mappings`
- Requires `seafarers`, `seafarer_family_members`, `countries`, `states`, `bank_account_types`, `banks`, `bank_branches`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_bank_accounts` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `countries`, `states`, `workflow_status`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 9

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Check if any mappings already exist fo | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `states_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `countries_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `account_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `family_member_id_mapping` | Seafarer ID mapping (from migration.table_m | `legacy_uuid`, `new_id` | - | - |
| `bank_id_mapping` | FK lookup | `DISTINCT ON (TRIM(UPPER(bank_code))) bank_id`, `ifsc_code_normalized` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `branch_id_mapping` | Countries ID mapping (from smac_master | `DISTINCT ON (TRIM(UPPER(branch_code))) branch_id`, `ifsc_code_normalized` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `beneficiary_type_id_mapping` | FK lookup | `family_uuid`, `beneficiary_type_id` | - | `synergy_seafarer` |
| `workflow_status_mapping` | FK lookup | `workflow_status_id`, `status_name_normalized`, `workflow_status_code` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Purpose**: Check if any mappings already exist fo
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `states_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE states_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''states'''
) AS t(source_id text, target_id uuid);
```

### `countries_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''countries'''
) AS t(source_id text, target_id uuid);
```

### `account_type_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE account_type_id_mapping AS
SELECT
    t.source_id::integer as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''bank_account_types'''
) AS t(source_id text, target_id uuid);
```

### `family_member_id_mapping`

- **Purpose**: Seafarer ID mapping (from migration.table_m
- **Output columns**: legacy_uuid, new_id

```sql
CREATE TEMP TABLE family_member_id_mapping AS
SELECT DISTINCT
    fm.id as legacy_uuid,
    fm.id as new_id
FROM public.seafarer_family_members fm
WHERE fm.id IS NOT NULL;
```

### `bank_id_mapping`

- **Output columns**: DISTINCT ON (TRIM(UPPER(bank_code))) bank_id, ifsc_code_normalized
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE bank_id_mapping AS
SELECT DISTINCT ON (TRIM(UPPER(bank_code)))
    bank_id,
    TRIM(UPPER(bank_code)) as ifsc_code_normalized
FROM dblink('smac_master_migration',
    'SELECT tm.target_id as bank_id, TRIM(UPPER(b.code)) as bank_code
     FROM migration.table_mappings tm
     INNER JOIN public.banks b ON b.id = tm.target_id
     WHERE tm.target_table = ''banks'''
) AS t(bank_id uuid, bank_code text)
WHERE bank_code IS NOT NULL
ORDER BY TRIM(UPPER(bank_code)), bank_id;
```

### `branch_id_mapping`

- **Purpose**: Countries ID mapping (from smac_master
- **Output columns**: DISTINCT ON (TRIM(UPPER(branch_code))) branch_id, ifsc_code_normalized
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE branch_id_mapping AS
SELECT DISTINCT ON (TRIM(UPPER(branch_code)))
    branch_id,
    TRIM(UPPER(branch_code)) as ifsc_code_normalized
FROM dblink('smac_master_migration',
    'SELECT tm.target_id as branch_id, TRIM(UPPER(bb.code)) as branch_code
     FROM migration.table_mappings tm
     INNER JOIN public.bank_branches bb ON bb.id = tm.target_id
     WHERE tm.target_table = ''bank_branches'''
) AS t(branch_id uuid, branch_code text)
WHERE branch_code IS NOT NULL
ORDER BY TRIM(UPPER(branch_code)), branch_id;
```

### `beneficiary_type_id_mapping`

- **Output columns**: family_uuid, beneficiary_type_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE beneficiary_type_id_mapping AS
SELECT DISTINCT
    TRIM(legacy_bank.family_uuid)::uuid as family_uuid,
    CASE

        WHEN UPPER(TRIM(t.relation_name)) IN ('MOTHER', 'FATHER') THEN t.parent_beneficiary_type_id

        ELSE t.beneficiary_type_id
    END as beneficiary_type_id
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT TRIM(family_uuid) as family_uuid FROM public.bank_details WHERE family_uuid IS NOT NULL AND TRIM(family_uuid) != '''''
) AS legacy_bank(family_uuid varchar)
JOIN public.seafarer_family_members fm ON fm.id = TRIM(legacy_bank.family_uuid)::uuid
JOIN dblink('smac_master_migration',
    'SELECT
        fr.id as relation_id,
        fr.name as relation_name,
        bt.id as beneficiary_type_id,
        parent_bt.id as parent_beneficiary_type_id
     FROM public.family_relations fr
     LEFT JOIN public.beneficiary_types bt ON UPPER(TRIM(bt.name)) = UPPER(TRIM(fr.name))
     LEFT JOIN public.beneficiary_types parent_bt ON UPPER(TRIM(parent_bt.name)) = ''PARENT'''
) AS t(relation_id uuid, relation_name varchar, beneficiary_type_id uuid, parent_beneficiary_type_id uuid)
ON t.relation_id = fm.relation_id
WHERE legacy_bank.family_uuid IS NOT N...
```

### `workflow_status_mapping`

- **Output columns**: workflow_status_id, status_name_normalized, workflow_status_code
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_mapping AS
SELECT
    t.id as workflow_status_id,
    UPPER(TRIM(t.name)) as status_name_normalized,
    t.code as workflow_status_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM public.workflow_status'
) AS t(id uuid, name varchar, code varchar);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid`; idempotent via `id_mappings` |
| 2 | `seafarer_uuid`, `seafarer_id` | varchar, bigint | `seafarer_id` | uuid | Direct match `seafarers.id = TRIM(seafarer_uuid)::uuid`; fallback `seafarer_id_mapping`; nil UUID default | NOT NULL; lookup: `migration.table_mappings` (`seafarers`) |
| 3 | `family_uuid` (derived) | varchar | `beneficiary_type_id` | uuid | Join `beneficiary_type_id_mapping` on `family_uuid`; Mother/Father → Parent | Via `seafarer_family_members.relation_id` → `beneficiary_types` |
| 4 | `family_uuid` | varchar | `family_member_id` | uuid | Join `family_member_id_mapping` on `TRIM(family_uuid)::uuid` | Maps to `seafarer_family_members.id` |
| 5 | `beneficiary_name` | varchar | `beneficiary_name` | text | `COALESCE(NULLIF(TRIM(beneficiary_name), ''), '')` | NOT NULL; empty string when missing |
| 6 | `beneficiary_address` | varchar | `beneficiary_address` | text | `TRIM(beneficiary_address)` | Direct copy |
| 7 | `city` | varchar | `beneficiary_city` | text | `TRIM(city)` | Same source `city` used for beneficiary address |
| 8 | `state_id` | bigint | `beneficiary_state_id` | uuid | Map via `states_id_mapping` | Lookup: `smac_master_migration` → `states` |
| 9 | `country_id` | bigint | `beneficiary_country_id` | uuid | Map via `countries_id_mapping` | Lookup: `smac_master_migration` → `countries` |
| 10 | `contact` | varchar | `beneficiary_contact` | text | `TRIM(contact)` | Also copied to bank `contact` column |
| 11 | — | — | `account_nickname` | text | `NULL` | No SAC equivalent |
| 12 | `account_type` | integer | `account_type_id` | uuid | Map via `account_type_id_mapping` | Lookup: `bank_account_types` |
| 13 | — | — | `currency_id` | uuid | `NULL` | No SAC equivalent |
| 14 | `is_primary_account` | boolean | `is_primary` | boolean | `COALESCE(is_primary_account, false)` | Direct mapping |
| 15 | `is_overseas_account` | boolean | `is_overseas_account` | boolean | `COALESCE(is_overseas_account, false)` | Direct mapping |
| 16 | `ifsc_code` (derived) | varchar | `bank_id` | uuid | - | - |
| 17 | `bank_name` | varchar | `bank_name` | text | `TRIM(bank_name)` | Direct copy |
| 18 | `ifsc_code` (derived) | varchar | `branch_id` | uuid | - | - |
| 19 | `branch_name` | varchar | `branch_name` | text | `TRIM(branch_name)` | Direct copy |
| 20 | `address` | varchar | `bank_address` | text | `TRIM(address)` | Bank address from SAC `address` |
| 21 | `city` | varchar | `bank_city` | text | `TRIM(city)` | Same source `city` reused for bank |
| 22 | `state_id` | bigint | `bank_state_id` | uuid | Map via `states_id_mapping` | Same `state_id` as beneficiary |
| 23 | `country_id` | bigint | `bank_country_id` | uuid | Map via `countries_id_mapping` | Same `country_id` as beneficiary |
| 24 | `contact` | varchar | `contact` | text | `TRIM(contact)` | Bank contact |
| 25 | `account_number` | varchar | `account_number` | text | `TRIM(account_number)` | NOT NULL in SMAC |
| 26 | — | — | `masked_account_number` | text | `NULL` | No SAC equivalent |
| 27 | `iban_code` | varchar | `iban` | text | `TRIM(iban_code)` | Column rename |
| 28 | `swift_code` | varchar | `swift_bic` | text | `TRIM(swift_code)` | Column rename |
| 29 | `ifsc_code` | varchar | `ifsc_code` | text | `TRIM(ifsc_code)` | Direct copy |
| 30 | — | — | `aba_routing_number` | text | `NULL` | No SAC equivalent |
| 31 | — | — | `sort_code` | text | `NULL` | No SAC equivalent |
| 32 | — | — | `bsb_number` | text | `NULL` | No SAC equivalent |
| 33 | — | — | `transit_number` | text | `NULL` | No SAC equivalent |
| 34 | — | — | `clabe_number` | text | `NULL` | No SAC equivalent |
| 35 | — | — | `bank_code` | text | `NULL` | No SAC equivalent |
| 36 | — | — | `branch_code` | text | `NULL` | No SAC equivalent |
| 37 | — | — | `payout_method_id` | uuid | `NULL` | No SAC equivalent |
| 38 | `reviewers` | jsonb | `reviewers` | jsonb | `COALESCE(reviewers, '[]'::jsonb)` | Default empty array |
| 39 | `workflow_uid` | varchar | `workflow_uid` | text | `TRIM(workflow_uid)` | Direct copy |
| 40 | `comments` | varchar | `comments` | text | `TRIM(comments)` | Direct copy |
| 41 | — | — | `supporting_data` | jsonb | `NULL` | No SAC equivalent |
| 42 | `status` | varchar | `workflow_status_id` | uuid | LATERAL join `workflow_status_mapping`; SignOn Pending→Submitted, Request Change→In Review; default Draft | Lookup: `public.workflow_status` (`smac_master_migration`) |
| 43 | — | — | `is_verified` | boolean | Hardcoded `false` | Not in SAC |
| 44 | — | — | `verified_at` | timestamp | `NULL` | No SAC equivalent |
| 45 | — | — | `verified_by_id` | uuid | `NULL` | No SAC equivalent |
| 46 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 47 | — | — | `rejection_reason_id` | uuid | `NULL` | No SAC equivalent |
| 48 | `deleted_at` | timestamp | `status` | text | `'deleted'` when `deleted_at IS NOT NULL`, else `'active'` | Case 1: `deleted_at` drives status |
| 49 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 50 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 51 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 52 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 53 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 54 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` — names combined into `notes` | `legacy_id` not in audit_info (handled by `id_mappings`) |

**SMAC columns not migrated:** `masked_account_number`, `currency_id`, `account_nickname`, `payout_method_id`, routing fields (`aba_routing_number`, `sort_code`, `bsb_number`, `transit_number`, `clabe_number`, `bank_code`, `branch_code`), verification fields — no SAC source equivalents.

**SAC columns not migrated:** None — all `bank_details` columns referenced in migration script are mapped or used in lookups.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`
- `seafarers`
- `states`
- `workflow_status`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Check if any mappings already exist fo
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. States ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE states_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''states'''
) AS t(source_id text, target_id uuid);
```

### 3. Countries ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''countries'''
) AS t(source_id text, target_id uuid);
```

### 4. Account Type ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE account_type_id_mapping AS
SELECT
    t.source_id::integer as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''bank_account_types'''
) AS t(source_id text, target_id uuid);
```

### 5. Family Member ID Mapping
**Purpose**: Seafarer ID mapping (from migration.table_m
**Output columns**: `legacy_uuid, new_id`

```sql
CREATE TEMP TABLE family_member_id_mapping AS
SELECT DISTINCT
    fm.id as legacy_uuid,
    fm.id as new_id
FROM public.seafarer_family_members fm
WHERE fm.id IS NOT NULL;
```

### 6. Bank ID Mapping
**Output columns**: `DISTINCT ON (TRIM(UPPER(bank_code))) bank_id, ifsc_code_normalized`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE bank_id_mapping AS
SELECT DISTINCT ON (TRIM(UPPER(bank_code)))
    bank_id,
    TRIM(UPPER(bank_code)) as ifsc_code_normalized
FROM dblink('smac_master_migration',
    'SELECT tm.target_id as bank_id, TRIM(UPPER(b.code)) as bank_code
     FROM migration.table_mappings tm
     INNER JOIN public.banks b ON b.id = tm.target_id
     WHERE tm.target_table = ''banks'''
) AS t(bank_id uuid, bank_code text)
WHERE bank_code IS NOT NULL
ORDER BY TRIM(UPPER(bank_code)), bank_id;
```

### 7. Branch ID Mapping
**Purpose**: Countries ID mapping (from smac_master
**Output columns**: `DISTINCT ON (TRIM(UPPER(branch_code))) branch_id, ifsc_code_normalized`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE branch_id_mapping AS
SELECT DISTINCT ON (TRIM(UPPER(branch_code)))
    branch_id,
    TRIM(UPPER(branch_code)) as ifsc_code_normalized
FROM dblink('smac_master_migration',
    'SELECT tm.target_id as branch_id, TRIM(UPPER(bb.code)) as branch_code
     FROM migration.table_mappings tm
     INNER JOIN public.bank_branches bb ON bb.id = tm.target_id
     WHERE tm.target_table = ''bank_branches'''
) AS t(branch_id uuid, branch_code text)
WHERE branch_code IS NOT NULL
ORDER BY TRIM(UPPER(branch_code)), branch_id;
```

### 8. Beneficiary Type ID Mapping
**Output columns**: `family_uuid, beneficiary_type_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE beneficiary_type_id_mapping AS
SELECT DISTINCT
    TRIM(legacy_bank.family_uuid)::uuid as family_uuid,
    CASE

        WHEN UPPER(TRIM(t.relation_name)) IN ('MOTHER', 'FATHER') THEN t.parent_beneficiary_type_id

        ELSE t.beneficiary_type_id
    END as beneficiary_type_id
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT TRIM(family_uuid) as family_uuid FROM public.bank_details WHERE family_uuid IS NOT NULL AND TRIM(family_uuid) != '''''
) AS legacy_bank(family_uuid varchar)
JOIN public.seafarer_family_members fm ON fm.id = TRIM(legacy_bank.family_uuid)::uuid
JOIN dblink('smac_master_migration',
    'SELECT
        fr.id as relation_id,
        fr.name as relation_name,
        bt.id as beneficiary_type_id,
        parent_bt.id as parent_beneficiary_type_id
     FROM public.family_relations fr
     LEFT JOIN public.beneficiary_types bt ON UPPER(TRIM(bt.name)) = UPPER(TRIM(fr.name))
     LEFT JOIN public.beneficiary_types parent_bt ON UPPER(TRIM(parent_bt.name)) = ''PARENT'''
) AS t(relation_id uuid, relation_name varchar, beneficiary_type_id uuid, parent_beneficiary_type_id uuid)
ON t.relation_id = fm.relation_id
WHERE legacy_bank.family_uuid IS NOT NULL AND TRIM(legacy_bank.family_uuid) != '';
```

### 9. Workflow Status ID Mapping
**Output columns**: `workflow_status_id, status_name_normalized, workflow_status_code`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_mapping AS
SELECT
    t.id as workflow_status_id,
    UPPER(TRIM(t.name)) as status_name_normalized,
    t.code as workflow_status_code
FROM dblink('smac_master_migration',
    'SELECT id, name, code FROM public.workflow_status'
) AS t(id uuid, name varchar, code varchar);
```

Full migration context: `04-migration-scripts/crewing/seafarer_bank_accounts_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_bank_accounts_validation.sql` if available
- Run `06-rollback/crewing/seafarer_bank_accounts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
