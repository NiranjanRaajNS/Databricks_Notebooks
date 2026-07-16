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

- Migrates only attachments where file_path IS NOT NULL from contract_requests table
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Contract request attachments migration

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_requests'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | seafarer_id | - | seafarer_id | - | COALESCE( seafarer_contracts.seafarer_id, NULL::uuid ) AS seafarer_id | COALESCE( seafarer_contracts.seafarer_id, NULL::uuid ) |
| 3 | original_file_name | - | file_name | - | COALESCE(NULLIF(TRIM(legacy_data.original_file_name), ''), 'unnamed_file') as file_name | COALESCE(NULLIF(TRIM(legacy_data.original_file_name), ''), 'unnamed_file') |
| 4 | derived | - | file_type | - | 'contract_requests' as file_type | 'contract_requests' |
| 5 | - | - | file_sub_type | - | NULL | NULL::text |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | content_type | - | file_content_type | - | COALESCE(NULLIF(TRIM(legacy_data.content_type), ''), '') as file_content_type | COALESCE(NULLIF(TRIM(legacy_data.content_type), ''), '') |
| 8 | content_size | - | file_size | - | COALESCE(legacy_data.content_size::bigint, 0) as file_size | COALESCE(legacy_data.content_size::bigint, 0) |
| 9 | file_path | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.file_path), ''), '') as file_url | COALESCE(NULLIF(TRIM(legacy_data.file_path), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'contract_requests' as reference_entity | 'contract_requests' |
| 12 | derived | - | reference_id | - | contract_requests_map.new_id as reference_id | contract_requests_map.new_id |
| 13 | derived | - | version_number | - | 1 as version_number | 1 |
| 14 | - | - | valid_from | - | NULL | NULL::date as valid_ |
| 15 | - | - | valid_until | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | tenant_id | - | See source script | See source script |
| 18 | - | - | created_at | - | See source script | See source script |
| 19 | - | - | updated_at | - | See source script | See source script |
| 20 | - | - | archived_at | - | See source script | See source script |
| 21 | - | - | deleted_at | - | See source script | See source script |
| 22 | - | - | audit_info | - | See source script | See source script |

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
