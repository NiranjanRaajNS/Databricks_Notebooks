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

- SAC `id` (bigint) → SMAC `id` via `gen_random_uuid()` (not `resolve_target_id` — new UUID each run unless mappings exist separately)
- `contract_id` mapped when numeric via `contract_id_mapping` → `seafarer_contracts` (nullable)
- `contract_agreement_id` via `contract_agreement_id_mapping` → `contract_agreements`
- `reason_ids`: JSONB array mapped by ID/UUID/name; AMENDMENT type uses `ammentment_type` name lookup
- `attachments` aggregated from `contract_request_file_attachments` via `contract_request_attachments_mapping`
- `proposed_position_id` / `proposed_rank_id` from `meta_data` JSONB keys
- Requires `seafarer_contracts`, `contract_agreements`, `contract_request_reasons` migrated first

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
| 1 | `id` | bigint | `id` | uuid | `gen_random_uuid()` | New UUID per row (SAC bigint id not preserved as target id) |
| 2 | `contract_id` | text | `contract_id` | uuid | Map via `contract_id_mapping` when numeric; else NULL | Lookup: `seafarer_contracts`; nullable |
| 3 | `contract_agreement_id` | bigint | `contract_agreement_id` | uuid | Map via `contract_agreement_id_mapping` | Lookup: `contract_agreements`; nullable |
| 4 | `type` | character varying | `request_type` | text | `COALESCE(NULLIF(TRIM(type), ''), 'Unknown')` | NOT NULL |
| 5 | `status` | character varying | `request_status` | text | Map Approved/Pending/InReview/Rejected/Closed/Cancelled to enum text | NOT NULL |
| 6 | `reason_ids`, `ammentment_type`, `type` | jsonb, character varying | `reason_ids` | uuid[] | Array: map by reason ID, UUID, or name; AMENDMENT uses `ammentment_type` | Lookups: `contract_request_reason_id_mapping`, `contract_request_reason_name_mapping` |
| 7 | `additional_details` | text | `additional_details` | jsonb | Parse JSON or wrap as `{"text": ...}`; NULL if contains `-` | Nullable |
| 8 | `assignee_user_id` | text | `assigned_to` | uuid | Cast to UUID when valid format; else NULL | Nullable |
| 9 | `approvers` | jsonb | `approvers` | jsonb | Direct copy | Nullable |
| 10 | `id` (via file attachments) | bigint | `attachments` | uuid[] | `contract_request_attachments_mapping.attachment_uuids` | Lookup: `seafarer_attachments` mappings |
| 11 | `deleted_at`, `status` | timestamp, character varying | `status` | text | `deleted_at` or Closed/Cancelled/Rejected → `Inactive`; else `Active` | Record lifecycle status |
| 12 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 14 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | NOT NULL |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 16 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 17 | `meta_data` | jsonb | `applicable_date_of_promotion` | timestamp without time zone | Extract `ApplicableDateOfPromotion` / `applicableDateOfPromotion` | Nullable |
| 18 | `meta_data` → ProposedPositionId | jsonb | `proposed_position_id` | uuid | Map via `position_id_mapping` | Lookup: dblink `positions` |
| 19 | `meta_data` → ProposedRankId | jsonb | `proposed_rank_id` | uuid | Map via `rank_id_mapping` | Lookup: dblink `ranks` |
| 20 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | `legacy_id` in audit via id_mappings |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `reason`, `note`, `file_path`, `original_file_name`, `content_type`, `content_size`, `assignee_email`, `assignee_user_name`, `level_two_assignee_*`, `extension_*`, `sign_on_issue_type`, `task_id` — file fields migrated separately via `contract_request_attachments`; other fields not in target schema.

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
