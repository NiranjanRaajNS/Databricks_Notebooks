# Table Mapping: contract_requests → seafarer_attachments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_requests
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/contract_request_attachments_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_requests`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Contract Requests (`contract_requests` → `seafarer_attachments`)

## Migration Notes

- SAC `contract_requests` rows with `file_path IS NOT NULL` → SMAC `seafarer_attachments` (`reference_entity = 'contract_requests'`)
- `migration.resolve_target_id()` with `p_target_id = NULL` (SAC has bigint `id` only)
- `reference_id` from `contract_requests_id_mapping`; only rows with valid contract_requests mapping migrated
- `seafarer_id` resolved via `contract_id` → `seafarer_contracts.seafarer_id`
- `status`: ACTIVE/DELETED from `deleted_at`
- Requires `contract_requests` and `seafarer_contracts` migrated first

## Special Considerations

- Orchestration dependencies: `contract_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_requests_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `contract_id_to_seafarer_contracts_mapping` | FK lookup | `legacy_contract_id`, `seafarer_contract_id` | `migration.table_mappings` (see SQL) | - |

### `contract_requests_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=contract_requests

```sql
CREATE TEMP TABLE contract_requests_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_requests'
  AND target_db = current_database();
```

### `contract_id_to_seafarer_contracts_mapping`

- **Output columns**: legacy_contract_id, seafarer_contract_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_to_seafarer_contracts_mapping AS
SELECT DISTINCT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_contract_id,
    target_id AS seafarer_contract_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; filter `file_path IS NOT NULL` |
| 2 | `contract_id` | text | `seafarer_id` | uuid | `contract_id` → `seafarer_contracts` → `seafarer_id`; NULL if unmapped | Nullable in target |
| 3 | `original_file_name` | character varying | `file_name` | text | `COALESCE(NULLIF(TRIM(original_file_name), ''), 'unnamed_file')` | NOT NULL |
| 4 | — | — | `file_type` | text | Hardcoded `'contract_requests'` | SMAC attachment category |
| 5 | — | — | `file_sub_type` | text | `NULL` | No equivalent in SAC |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No equivalent in SAC |
| 7 | `content_type` | text | `file_content_type` | text | `COALESCE(NULLIF(TRIM(content_type), ''), '')` | NOT NULL |
| 8 | `content_size` | bigint | `file_size` | bigint | `COALESCE(content_size::bigint, 0)` | NOT NULL |
| 9 | `file_path` | text | `file_url` | text | `COALESCE(NULLIF(TRIM(file_path), ''), '')` | NOT NULL; migration filter requires non-NULL |
| 10 | — | — | `checksum` | text | `NULL` | No equivalent in SAC |
| 11 | — | — | `reference_entity` | text | Hardcoded `'contract_requests'` | Polymorphic reference |
| 12 | `id` | bigint | `reference_id` | uuid | Map via `contract_requests_id_mapping` | Required for migration (WHERE mapping exists) |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | SMAC default |
| 14 | — | — | `valid_from` | date | `NULL` | No equivalent in SAC |
| 15 | — | — | `valid_until` | date | `NULL` | No equivalent in SAC |
| 16 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `DELETED`; else `ACTIVE` | Text status |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | NOT NULL |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 21 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all fields NULL | SAC audit columns not used |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `type`, `status`, `reason`, `assignee_*`, `note`, `task_id`, `contract_agreement_id`, `reason_ids`, `approvers`, `meta_data`, `created_by_id`, `updated_by_id` — contract request fields; only file columns migrated to attachments.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_requests`
- `public.contract_requests`
- `public.seafarer_contracts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract Requests ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='contract_requests'`

```sql
CREATE TEMP TABLE contract_requests_id_mapping AS
SELECT DISTINCT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_requests'
  AND target_db = current_database();
```

### 2. Contract Id To Seafarer Contracts ID Mapping
**Output columns**: `legacy_contract_id, seafarer_contract_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_id_to_seafarer_contracts_mapping AS
SELECT DISTINCT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_contract_id,
    target_id AS seafarer_contract_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/contract_request_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/contract_request_attachments_validation.sql` if available
- Run `06-rollback/crewing/contract_request_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
