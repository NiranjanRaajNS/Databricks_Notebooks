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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates bank_details to seafarer_bank_accounts preserving UUID. Maps seafarer_uuid (varchar) to seafarer_id (uuid) via seafarers table in current database. Maps state_id and country_id from bigint to UUID via smac_master_migration. Sets default workflow_status_id to APPROVED. Builds audit_info from created_by/updated_by columns.

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
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'bank_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | seafarer_uuid | - | seafarer_id | - | COALESCE( CASE WHEN legacy_data.seafarer_uuid IS NOT NULL AND TRIM(legacy_data.seafarer_uuid) != '' THEN (SELECT id FROM public.seafarers WHERE id = TRIM(legacy_data.seafarer_uu... | COALESCE( CASE WHEN legacy_data.seafarer_uuid IS NOT NULL AND TRIM(legacy_data.seafarer_uuid) != '' THEN (SELECT id FROM public.seafarers WHERE id = TRIM(legacy_data.seafarer_uu... |
| 3 | derived | - | beneficiary_type_id | - | beneficiary_type_map.beneficiary_type_id AS beneficiary_type_id | beneficiary_type_map.beneficiary_type_id |
| 4 | derived | - | family_member_id | - | family_member_map.new_id AS family_member_id | family_member_map.new_id |
| 5 | beneficiary_name | - | beneficiary_name | - | COALESCE(NULLIF(TRIM(legacy_data.beneficiary_name), ''), '') as beneficiary_name | COALESCE(NULLIF(TRIM(legacy_data.beneficiary_name), ''), '') |
| 6 | beneficiary_address | - | beneficiary_address | - | TRIM(legacy_data.beneficiary_address) as beneficiary_address | TRIM(legacy_data.beneficiary_address) |
| 7 | city | - | beneficiary_city | - | TRIM(legacy_data.city) as beneficiary_city | TRIM(legacy_data.city) |
| 8 | derived | - | beneficiary_state_id | - | beneficiary_state_map.new_id AS beneficiary_state_id | beneficiary_state_map.new_id |
| 9 | derived | - | beneficiary_country_id | - | beneficiary_country_map.new_id AS beneficiary_country_id | beneficiary_country_map.new_id |
| 10 | contact | - | beneficiary_contact | - | TRIM(legacy_data.contact) as beneficiary_contact | TRIM(legacy_data.contact) |
| 11 | - | - | account_nickname | - | NULL | NULL::text |
| 12 | derived | - | account_type_id | - | account_type_map.new_id AS account_type_id | account_type_map.new_id |
| 13 | - | - | currency_id | - | NULL | NULL::uuid |
| 14 | is_primary_account | - | is_primary | - | COALESCE(legacy_data.is_primary_account, false) as is_primary | COALESCE(legacy_data.is_primary_account, false) |
| 15 | is_overseas_account | - | is_overseas_account | - | COALESCE(legacy_data.is_overseas_account, false) as is_overseas_account | COALESCE(legacy_data.is_overseas_account, false) |
| 16 | derived | - | bank_id | - | bank_id_mapping.bank_id as bank_id | bank_id_mapping.bank_id |
| 17 | bank_name | - | bank_name | - | TRIM(legacy_data.bank_name) as bank_name | TRIM(legacy_data.bank_name) |
| 18 | derived | - | branch_id | - | branch_id_mapping.branch_id as branch_id | branch_id_mapping.branch_id |
| 19 | branch_name | - | branch_name | - | TRIM(legacy_data.branch_name) as branch_name | TRIM(legacy_data.branch_name) |
| 20 | address | - | bank_address | - | TRIM(legacy_data.address) as bank_address | TRIM(legacy_data.address) |
| 21 | city | - | bank_city | - | TRIM(legacy_data.city) as bank_city | TRIM(legacy_data.city) |
| 22 | derived | - | bank_state_id | - | bank_state_map.new_id AS bank_state_id | bank_state_map.new_id |
| 23 | derived | - | bank_country_id | - | bank_country_map.new_id AS bank_country_id | bank_country_map.new_id |
| 24 | contact | - | contact | - | TRIM(legacy_data.contact) as contact | TRIM(legacy_data.contact) |
| 25 | account_number | - | account_number | - | TRIM(legacy_data.account_number) as account_number | TRIM(legacy_data.account_number) |
| 26 | - | - | masked_account_number | - | NULL | NULL::text |
| 27 | iban_code | - | iban | - | TRIM(legacy_data.iban_code) as iban | TRIM(legacy_data.iban_code) |
| 28 | swift_code | - | swift_bic | - | TRIM(legacy_data.swift_code) as swift_bic | TRIM(legacy_data.swift_code) |
| 29 | ifsc_code | - | ifsc_code | - | TRIM(legacy_data.ifsc_code) as ifsc_code | TRIM(legacy_data.ifsc_code) |
| 30 | - | - | aba_routing_number | - | NULL | NULL::text |
| 31 | - | - | sort_code | - | NULL | NULL::text |
| 32 | - | - | bsb_number | - | NULL | NULL::text |
| 33 | - | - | transit_number | - | NULL | NULL::text |
| 34 | - | - | clabe_number | - | NULL | NULL::text |
| 35 | - | - | bank_code | - | NULL | NULL::text |
| 36 | - | - | branch_code | - | NULL | NULL::text |
| 37 | - | - | payout_method_id | - | NULL | NULL::uuid |
| 38 | reviewers | - | reviewers | - | COALESCE(legacy_data.reviewers, '[]'::jsonb) as reviewers | COALESCE(legacy_data.reviewers, '[]'::jsonb) |
| 39 | workflow_uid | - | workflow_uid | - | TRIM(legacy_data.workflow_uid) as workflow_uid | TRIM(legacy_data.workflow_uid) |
| 40 | comments | - | comments | - | TRIM(legacy_data.comments) as comments | TRIM(legacy_data.comments) |
| 41 | - | - | supporting_data | - | NULL | NULL::jsonb |
| 42 | derived | - | workflow_status_id | - | COALESCE( workflow_status_map.workflow_status_id, (SELECT workflow_status_id FROM workflow_status_mapping WHERE status_name_normalized = 'DRAFT' LIMIT 1) ) as workflow_status_id | COALESCE( workflow_status_map.workflow_status_id, (SELECT workflow_status_id FROM workflow_status_mapping WHERE status_name_normalized = 'DRAFT' LIMIT 1) ) |
| 43 | derived | - | is_verified | - | false as is_verified | false |
| 44 | - | - | verified_at | - | NULL | NULL::timestamp |
| 45 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 46 | - | - | verification_notes | - | NULL | NULL::text |
| 47 | - | - | rejection_reason_id | - | NULL | NULL::uuid |
| 48 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'deleted'::text ELSE 'active'::text END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'deleted'::text ELSE 'active'::text END |
| 49 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 50 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 51 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 52 | - | - | archived_at | - | NULL | NULL::timestamp |
| 53 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 54 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
