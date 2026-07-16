# Table Mapping: audits → seafarer_contract_audit_logs

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: audits
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_contract_audit_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_contract_audit_logs_migration.sql`

- **Legacy Path**: `synergy_manning.public.audits`
- **New Path**: `smac_crewing_migration.public.seafarer_contract_audit_logs`

## Business Key

- **Composite Key**: (`primary_reference_id`, `action`, `created_at`)
- **Source (orchestration)**: Seafarer Contract Audit Logs (`audits` → `seafarer_contract_audit_logs`)

## Migration Notes

- Only migrates records where auditable_type = 'Contract'
- Maps auditable_id (bigint) to primary_reference_id (uuid) via seafarer_contracts lookup
- Maps created_by_id (varchar) to user_id (uuid) - parses UUID if valid format
- Maps tenant (varchar) to tenant_id (uuid) via tenants lookup, fallback to DEFAULT_TENANT_ID
- Infers status from action field (Active/Archived/Deleted as text)
- Requires seafarer_contracts to be migrated first
- Migrates seafarer_contract_audit_logs from audits table. Only migrates records where auditable_type = 'Contract'. Generates new UUIDs for id column (source has bigint, no uuid column). Maps auditable_id (bigint) to primary_reference_id (uuid) via seafarer_contracts lookup using migration.table_mappings. Maps created_by_id (varchar) to user_id (uuid) - parses UUID if valid format, otherwise NULL. Maps tenant (varchar) to tenant_id (uuid) via tenants lookup, fallback to DEFAULT_TENANT_ID. Infers status from action field (Active/Archived/Deleted). Stores app_name, created_by_email, created_by_name, created_by_role, tenant, auditable_type, entity_type, and legacy_entity_id in audit_info JSONB. Requires seafarer_contracts to be migrated first.

## Special Considerations

- Stores app_name, created_by_email, and other metadata in audit_info JSONB
- Script performs `TRUNCATE TABLE public.seafarer_contract_audit_logs` before insert (full table reload).
- Orchestration dependencies: `seafarer_contracts`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_id_mapping` | - Maps auditable_id (bigint) to primary_reference_id (uuid) via seafarer_contracts lookup | `legacy_id`, `new_id` | `?.?.vessel_contracts` → `?.?.seafarer_contracts` | - |

### `contract_id_mapping`

- **Purpose**: - Maps auditable_id (bigint) to primary_reference_id (uuid) via seafarer_contracts lookup
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: source_table=vessel_contracts, target_table=seafarer_contracts

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
  AND source_table = 'vessel_contracts'
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | created_by_id | - | user_id | - | CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) <> '' AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a... | CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id) <> '' AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a... |
| 3 | action | - | action | - | NULLIF(TRIM(legacy_data.action), '') as action | NULLIF(TRIM(legacy_data.action), '') |
| 4 | audited_changes | - | audited_changes | - | legacy_data.audited_changes as audited_changes | legacy_data.audited_changes |
| 5 | derived | - | primary_reference_id | - | contract_mapping.new_id as primary_reference_id | contract_mapping.new_id |
| 6 | entity_reference | - | entity_reference | - | NULLIF(TRIM(legacy_data.entity_reference), '') as entity_reference | NULLIF(TRIM(legacy_data.entity_reference), '') |
| 7 | - | - | entity_id | - | NULL | NULL::uuid |
| 8 | device | - | device | - | NULLIF(TRIM(legacy_data.device), '') as device | NULLIF(TRIM(legacy_data.device), '') |
| 9 | ip_address | - | ip_address | - | NULLIF(TRIM(legacy_data.ip_address), '') as ip_address | NULLIF(TRIM(legacy_data.ip_address), '') |
| 10 | action | - | status | - | CASE WHEN UPPER(TRIM(legacy_data.action)) IN ('DELETE', 'DESTROY', 'REMOVE') THEN 'Deleted'::text WHEN UPPER(TRIM(legacy_data.action)) IN ('ARCHIVE') THEN 'Archived'::text WHEN ... | CASE WHEN UPPER(TRIM(legacy_data.action)) IN ('DELETE', 'DESTROY', 'REMOVE') THEN 'Deleted'::text WHEN UPPER(TRIM(legacy_data.action)) IN ('ARCHIVE') THEN 'Archived'::text WHEN ... |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 13 | - | - | archived_at | - | NULL | NULL::timestamp |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 15 | - | - | tenant_id | - | DEFAULT_TENANT_ID | COALESCE(tenant_mapping.tenant_id, :'DEFAULT_TENANT_ID'::uuid) |
| 16 | created_by_id, created_by_name, created_by_role, created_by_email, app_name, tenant, auditable_type, entity_type, entity_id | - | audit_info | - | jsonb_build_object( 'created_by', legacy_data.created_by_id, 'created_by_name', NULLIF(TRIM(legacy_data.created_by_name), ''), 'created_by_role', NULLIF(TRIM(legacy_data.created... | jsonb_build_object( 'created_by', legacy_data.created_by_id, 'created_by_name', NULLIF(TRIM(legacy_data.created_by_name), ''), 'created_by_role', NULLIF(TRIM(legacy_data.created... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_contracts`
- `seafarer_contracts`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract ID Mapping
**Purpose**: - Maps auditable_id (bigint) to primary_reference_id (uuid) via seafarer_contracts lookup
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `vessel_contracts` → `seafarer_contracts`

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
  AND source_table = 'vessel_contracts'
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_contract_audit_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_contract_audit_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_contract_audit_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
