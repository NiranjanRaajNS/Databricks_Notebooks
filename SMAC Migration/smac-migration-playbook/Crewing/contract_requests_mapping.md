# Table Mapping: contract_requests → contract_requests

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_requests
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: contract_requests
- **Source Script**: `04-migration-scripts/crewing/contract_requests_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_requests`
- **New Path**: `smac_crewing_migration.public.contract_requests`

## Business Key

- **Composite Key**: (`contract_id`, `type`, `created_at`)
- **Source (orchestration)**: Contract Requests (`contract_requests` → `contract_requests`)

## Migration Notes

- Generates new UUID for id (source has bigint, no uuid column)
- Maps contract_id from contract_id (bigint) via migration.table_mappings to seafarer_contracts
- Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements
- Maps request_type from type (varchar(20), NOT NULL)
- Maps request_status from status (varchar(10), NOT NULL)
- Maps assigned_to from assignee_user_id (text) - parses as UUID if valid format
- Maps attachments from contract_request_file_attachments table - aggregates attachment_id (bigint) mapped to UUID via migration.table_mappings for seafarer_attachments
- Maps status from status (varchar(10), NOT NULL)
- Sets default values: tenant_id (DEFAULT_TENANT_ID)
- Maps attachments from contract_request_file_attachments table (requires file_attachments to be migrated for complete mapping)
- Requires seafarer_contracts and contract_agreements to be migrated first
- Migrates contract_requests table. Generates new UUIDs for id column (source has bigint, no uuid column). Maps contract_id from contract_id (bigint) via migration.table_mappings to seafarer_contracts (nullable in target). Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements (nullable in target). Maps request_type from type (varchar(20), NOT NULL). Maps request_status and status from status (varchar(10), NOT NULL). Maps reason_ids from reason_ids (jsonb) - converts to uuid array if possible. Maps additional_details from additional_details (text) - converts to jsonb. Maps assigned_to from assignee_user_id (text) - parses as UUID if valid format. Maps approvers from approvers (jsonb) - direct copy. Sets attachments to NULL (not directly mappable from source). Sets defaults: tenant_id (DEFAULT_TENANT_ID), archived_at (NULL). Uses standardized SMAC audit_info structure. Requires seafarer_contracts and contract_agreements to be migrated first.

## Special Considerations

- Maps reason_ids from reason_ids (jsonb) - converts to uuid array if possible
- Maps additional_details from additional_details (text) - converts to jsonb
- Maps approvers from approvers (jsonb) - direct copy
- Script performs `TRUNCATE TABLE public.contract_requests` before insert (full table reload).
- Orchestration dependencies: `seafarer_contracts`, `contract_agreements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `contract_agreement_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `contract_request_attachments_mapping` | FK lookup | `legacy_contract_request_id`, `attachment_uuids` | `migration.table_mappings` (see SQL) | `synergy_manning` |
| `rank_id_mapping` | Contract ID lo | `legacy_id`, `new_id` | - | `synergy_master` |
| `position_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `contract_request_reason_id_mapping` | FK lookup | `legacy_id`, `legacy_uuid`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

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

### `contract_request_attachments_mapping`

- **Output columns**: legacy_contract_request_id, attachment_uuids
- **migration.table_mappings**: target_table=seafarer_attachments
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_request_attachments_mapping AS
SELECT
    crfa.contract_request_id AS legacy_contract_request_id,
    ARRAY_AGG(DISTINCT sa_mapping.target_id) FILTER (WHERE sa_mapping.target_id IS NOT NULL) AS attachment_uuids
FROM dblink('synergy_manning',
    'SELECT contract_request_id, attachment_id
     FROM public.contract_request_file_attachments
     WHERE contract_request_id IS NOT NULL AND attachment_id IS NOT NULL'
) AS crfa(contract_request_id bigint, attachment_id bigint)
LEFT JOIN migration.table_mappings sa_mapping ON
    sa_mapping.target_table = 'seafarer_attachments'
    AND sa_mapping.target_db = current_database()
    AND sa_mapping.source_id = crfa.attachment_id::text
GROUP BY crfa.contract_request_id;
```

### `rank_id_mapping`

- **Purpose**: Contract ID lo
- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### `position_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### `contract_request_reason_id_mapping`

- **Output columns**: legacy_id, legacy_uuid, new_id
- **migration.table_mappings**: target_schema=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE contract_request_reason_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        WHEN source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN NULL::bigint
        ELSE NULL::bigint
    END AS legacy_id,
    CASE
        WHEN source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN source_id::uuid
        ELSE NULL::uuid
    END AS legacy_uuid,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''contract_request_reasons'' AND target_schema = ''crewing'''
) AS tm(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| - | - | - | - | - | - | No INSERT mapping found; see source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_agreements`
- `public.contract_agreements`
- `public.relief_summary`
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

### 2. Contract Agreement ID Mapping
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

### 3. Contract Request Attachments ID Mapping
**Output columns**: `legacy_contract_request_id, attachment_uuids`
**migration.table_mappings**: `target_table='seafarer_attachments'`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE contract_request_attachments_mapping AS
SELECT
    crfa.contract_request_id AS legacy_contract_request_id,
    ARRAY_AGG(DISTINCT sa_mapping.target_id) FILTER (WHERE sa_mapping.target_id IS NOT NULL) AS attachment_uuids
FROM dblink('synergy_manning',
    'SELECT contract_request_id, attachment_id
     FROM public.contract_request_file_attachments
     WHERE contract_request_id IS NOT NULL AND attachment_id IS NOT NULL'
) AS crfa(contract_request_id bigint, attachment_id bigint)
LEFT JOIN migration.table_mappings sa_mapping ON
    sa_mapping.target_table = 'seafarer_attachments'
    AND sa_mapping.target_db = current_database()
    AND sa_mapping.source_id = crfa.attachment_id::text
GROUP BY crfa.contract_request_id;
```

### 4. Rank ID Mapping
**Purpose**: Contract ID lo
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### 5. Position ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### 6. Contract Request Reason ID Mapping
**Output columns**: `legacy_id, legacy_uuid, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE contract_request_reason_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        WHEN source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN NULL::bigint
        ELSE NULL::bigint
    END AS legacy_id,
    CASE
        WHEN source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN source_id::uuid
        ELSE NULL::uuid
    END AS legacy_uuid,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''contract_request_reasons'' AND target_schema = ''crewing'''
) AS tm(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/contract_requests_migration.sql`

## Validation

- Run `05-validation/crewing/contract_requests_validation.sql` if available
- Run `06-rollback/crewing/contract_requests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
