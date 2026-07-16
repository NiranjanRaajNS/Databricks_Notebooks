# Table Mapping: contract_signers → contract_signers

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_signers
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: contract_signers
- **Source Script**: `04-migration-scripts/crewing/contract_signers_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_signers`
- **New Path**: `smac_crewing_migration.public.contract_signers`

## Business Key

- **Composite Key**: (`contract_agreement_id`, `email`, `role`)
- **Source (orchestration)**: Contract Signers (`contract_signers` → `contract_signers`)

## Migration Notes

- Generates new UUID for id (source has bigint, no uuid column)
- Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements
- Maps user_id from user_id (text) or identity_user_id (varchar) - may be NULL if not UUID format
- Maps signature_status from status (varchar, default 'Pending')
- Maps is_signed from is_signed (boolean)
- Maps sign_mode from sign_mode (varchar, default 'Digital')
- Maps status from status (varchar, default 'Pending')
- Sets default values: signing_provider (NULL), certificate_hash (NULL), approval_level (1)
- Requires contract_agreements to be migrated first
- Migrates contract_signers table. Generates new UUIDs for id column (source has bigint, no uuid column). Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements. Maps user_id from user_id (text) or identity_user_id (varchar) - parses as UUID if valid format, otherwise NULL. Maps signature_status and status from status (varchar, default 'Pending'). Maps is_signed, signed_on, sign_mode, signing_url, is_active directly. Sets defaults for new fields: signing_provider (NULL), certificate_hash (NULL), approval_level (1), tenant_id (DEFAULT_TENANT_ID), created_at/updated_at (NOW()). Uses standardized SMAC audit_info structure. Requires contract_agreements to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.contract_signers` before insert (full table reload).
- Orchestration dependencies: `contract_agreements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_agreement_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_contracts_id_mapping` | FK lookup | `legacy_contract_id`, `new_contract_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_contracts_seafarer_lookup` | FK lookup | `contract_id`, `vc.seafarer_id` | - | `synergy_manning` |
| `seafarer_id_mapping` | FK lookup | `legacy_seafarer_id`, `new_seafarer_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_identity_profile_lookup` | FK lookup | `contract_id`, `s2ip.identity_profile_id` | - | - |

### `contract_agreement_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=contract_agreements

```sql
CREATE TEMP TABLE contract_agreement_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `seafarer_contracts_id_mapping`

- **Output columns**: legacy_contract_id, new_contract_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE seafarer_contracts_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_contract_id,
    target_id AS new_contract_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessel_contracts_seafarer_lookup`

- **Output columns**: contract_id, vc.seafarer_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE vessel_contracts_seafarer_lookup AS
SELECT DISTINCT
    vc.id AS contract_id,
    vc.seafarer_id
FROM dblink('synergy_manning',
    'SELECT id, seafarer_id FROM public.vessel_contracts WHERE id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS vc(id bigint, seafarer_id bigint)
INNER JOIN contract_signers_contract_ids csci ON csci.contract_id = vc.id;
```

### `seafarer_id_mapping`

- **Output columns**: legacy_seafarer_id, new_seafarer_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_seafarer_id,
    target_id AS new_seafarer_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `seafarer_identity_profile_lookup`

- **Output columns**: contract_id, s2ip.identity_profile_id

```sql
CREATE TEMP TABLE seafarer_identity_profile_lookup AS
SELECT DISTINCT
    vcsl.contract_id AS contract_id,
    s2ip.identity_profile_id
FROM vessel_contracts_seafarer_lookup vcsl
INNER JOIN seafarer_id_to_identity_profile s2ip ON s2ip.seafarer_id = vcsl.seafarer_id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_signers'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(1... |
| 2 | derived | - | contract_agreement_id | - | ca_mapping.new_id AS contract_agreement_id | ca_mapping.new_id |
| 3 | user_id, identity_user_id | - | user_id | - | COALESCE( CASE WHEN legacy_data.user_id IS NOT NULL AND legacy_data.user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.user_id::uuid ELS... | COALESCE( CASE WHEN legacy_data.user_id IS NOT NULL AND legacy_data.user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.user_id::uuid ELS... |
| 4 | email | - | email | - | NULLIF(TRIM(legacy_data.email), '') AS email | NULLIF(TRIM(legacy_data.email), '') |
| 5 | status | - | signature_status | - | COALESCE(NULLIF(TRIM(legacy_data.status), ''), 'Pending') AS signature_status | COALESCE(NULLIF(TRIM(legacy_data.status), ''), 'Pending') |
| 6 | is_signed | - | is_signed | - | COALESCE(legacy_data.is_signed, false) AS is_signed | COALESCE(legacy_data.is_signed, false) |
| 7 | signed_on | - | signed_on | - | legacy_data.signed_on AS signed_on | legacy_data.signed_on |
| 8 | sign_mode | - | sign_mode | - | COALESCE(NULLIF(TRIM(legacy_data.sign_mode), ''), 'Digital') AS sign_mode | COALESCE(NULLIF(TRIM(legacy_data.sign_mode), ''), 'Digital') |
| 9 | - | - | signing_provider | - | NULL | NULL::text |
| 10 | - | - | certificate_hash | - | NULL | NULL::text |
| 11 | signing_url | - | signing_url | - | NULLIF(TRIM(legacy_data.signing_url), '') AS signing_url | NULLIF(TRIM(legacy_data.signing_url), '') |
| 12 | is_active | - | is_active | - | COALESCE(legacy_data.is_active, true) AS is_active | COALESCE(legacy_data.is_active, true) |
| 13 | is_active | - | status | - | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END AS status | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END |
| 14 | derived | - | tenant_id | - | v_default_tenant_id AS tenant_id | v_default_tenant_id |
| 15 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 16 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 17 | - | - | archived_at | - | NULL | NULL::timestamp |
| 18 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 19 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 20 | role | - | approval_level | - | CASE WHEN UPPER(TRIM(legacy_data.role)) = 'SEAFARER' THEN 3 WHEN UPPER(TRIM(legacy_data.role)) = 'APPROVER' THEN 2 WHEN UPPER(TRIM(legacy_data.role)) = 'FLEETMANAGER' THEN 1 ELS... | CASE WHEN UPPER(TRIM(legacy_data.role)) = 'SEAFARER' THEN 3 WHEN UPPER(TRIM(legacy_data.role)) = 'APPROVER' THEN 2 WHEN UPPER(TRIM(legacy_data.role)) = 'FLEETMANAGER' THEN 1 ELS... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_agreements`
- `public.contract_agreements`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract Agreement ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='contract_agreements'`

```sql
CREATE TEMP TABLE contract_agreement_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Seafarer Contracts ID Mapping
**Output columns**: `legacy_contract_id, new_contract_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE seafarer_contracts_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_contract_id,
    target_id AS new_contract_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 3. Vessel Contracts Seafarer ID Mapping
**Output columns**: `contract_id, vc.seafarer_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE vessel_contracts_seafarer_lookup AS
SELECT DISTINCT
    vc.id AS contract_id,
    vc.seafarer_id
FROM dblink('synergy_manning',
    'SELECT id, seafarer_id FROM public.vessel_contracts WHERE id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS vc(id bigint, seafarer_id bigint)
INNER JOIN contract_signers_contract_ids csci ON csci.contract_id = vc.id;
```

### 4. Seafarer ID Mapping
**Output columns**: `legacy_seafarer_id, new_seafarer_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_seafarer_id,
    target_id AS new_seafarer_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 5. Seafarer Identity Profile ID Mapping
**Output columns**: `contract_id, s2ip.identity_profile_id`

```sql
CREATE TEMP TABLE seafarer_identity_profile_lookup AS
SELECT DISTINCT
    vcsl.contract_id AS contract_id,
    s2ip.identity_profile_id
FROM vessel_contracts_seafarer_lookup vcsl
INNER JOIN seafarer_id_to_identity_profile s2ip ON s2ip.seafarer_id = vcsl.seafarer_id;
```

Full migration context: `04-migration-scripts/crewing/contract_signers_migration.sql`

## Validation

- Run `05-validation/crewing/contract_signers_validation.sql` if available
- Run `06-rollback/crewing/contract_signers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
