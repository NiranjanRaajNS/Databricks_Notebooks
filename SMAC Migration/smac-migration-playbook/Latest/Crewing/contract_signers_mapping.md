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

- `migration.resolve_target_id()` with `p_target_id = NULL` (SAC bigint `id`)
- Only rows with valid `contract_agreement_id` mapping that exists in target `contract_agreements`
- `user_id`: parse `user_id` or `identity_user_id` as UUID; fallback `identity_profile_id` via contract → seafarer chain
- `signature_status` from SAC `status`; record `status` from `is_active` boolean
- `approval_level` from `role` (Seafarer=3, Approver=2, FleetManager=1)
- Batch insert (20k rows); `created_at`/`updated_at` = `NOW()`
- Requires `contract_agreements` migrated first

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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `contract_agreement_id` | bigint | `contract_agreement_id` | uuid | Map via `contract_agreement_id_mapping` | Required; must exist in `contract_agreements` |
| 3 | `user_id`, `identity_user_id`, `contract_id` | text, character varying, bigint | `user_id` | uuid | Parse UUID from user fields; fallback `seafarer_identity_profile_lookup` | Nullable |
| 4 | `email` | text | `email` | text | `NULLIF(TRIM(email), '')` | Nullable |
| 5 | `status` | character varying | `signature_status` | text | `COALESCE(NULLIF(TRIM(status), ''), 'Pending')` | NOT NULL |
| 6 | `is_signed` | boolean | `is_signed` | boolean | `COALESCE(is_signed, false)` | Default false |
| 7 | `signed_on` | timestamp without time zone | `signed_on` | timestamp without time zone | Direct copy | Nullable |
| 8 | `sign_mode` | character varying | `sign_mode` | text | `COALESCE(NULLIF(TRIM(sign_mode), ''), 'Digital')` | NOT NULL |
| 9 | — | — | `signing_provider` | text | `NULL` | No equivalent in SAC |
| 10 | — | — | `certificate_hash` | text | `NULL` | No equivalent in SAC |
| 11 | `signing_url` | text | `signing_url` | text | `NULLIF(TRIM(signing_url), '')` | Nullable |
| 12 | `is_active` | boolean | `is_active` | boolean | `COALESCE(is_active, true)` | Default true |
| 13 | `is_active` | boolean | `status` | text | `is_active = true` → `Active`; else `Inactive` | Record lifecycle status |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not sourced from SAC |
| 16 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not sourced from SAC |
| 17 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 18 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at` |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all fields NULL | Standardized SMAC audit |
| 20 | `role` | character varying | `approval_level` | integer | Seafarer→3, Approver→2, FleetManager→1; else 1 | NOT NULL |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `contract_id`, `name`, `identity_role_names`, `rank` — not mapped to SMAC columns (`contract_id` used only for user_id fallback chain).

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
