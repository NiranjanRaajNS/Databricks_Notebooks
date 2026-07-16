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

- Source: `synergy_manning.public.audits` filtered to `auditable_type = 'Contract'` only
- Source `id` is bigint — generates new UUID via `gen_random_uuid()` (no UUID column in SAC)
- `auditable_id` (bigint) → `primary_reference_id` via `contract_id_mapping` (`vessel_contracts` → `seafarer_contracts`); unmapped audits excluded
- `created_by_id` (varchar) cast to `user_id` (uuid) when valid UUID format; else NULL
- `tenant` (varchar) → `tenant_id` via `tenants` name lookup (`smac_master_migration`); fallback `DEFAULT_TENANT_ID`
- `status` inferred from `action` (Delete/Destroy/Remove → Deleted, Archive → Archived, else Active)
- Custom `audit_info` JSONB stores metadata not mapped to SMAC columns (`app_name`, `created_by_email`, `legacy_entity_id`, etc.)
- Requires `seafarer_contracts` migrated first

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
| 1 | `id` | bigint | `id` | uuid | `gen_random_uuid()` | New UUID per row; SAC has bigint `id` only |
| 2 | `created_by_id` | varchar | `user_id` | uuid | Cast to UUID when valid UUID regex; else NULL | SAC stores user ref as varchar |
| 3 | `action` | varchar | `action` | text | `NULLIF(TRIM(action), '')` | Direct copy |
| 4 | `audited_changes` | jsonb | `audited_changes` | jsonb | Direct copy | Audit payload preserved |
| 5 | `auditable_id` | bigint | `primary_reference_id` | uuid | Map via `contract_id_mapping` (`vessel_contracts` → `seafarer_contracts`) | Required; unmapped rows filtered out |
| 6 | `entity_reference` | varchar | `entity_reference` | text | `NULLIF(TRIM(entity_reference), '')` | Direct copy |
| 7 | `entity_id` | bigint | `entity_id` | uuid | `NULL` | Source bigint not mapped to uuid (entity_type varies) |
| 8 | `device` | varchar | `device` | text | `NULLIF(TRIM(device), '')` | Direct copy |
| 9 | `ip_address` | varchar | `ip_address` | text | `NULLIF(TRIM(ip_address), '')` | Direct copy |
| 10 | `action` (derived) | varchar | `status` | text | Delete/Destroy/Remove → `Deleted`; Archive → `Archived`; else `Active` | Inferred from audit action |
| 11 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 13 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 14 | — | — | `deleted_at` | timestamp | `NULL` | SAC audits have no `deleted_at` |
| 15 | `tenant` | varchar | `tenant_id` | uuid | LATERAL join `tenants` by name; fallback `:'DEFAULT_TENANT_ID'::uuid` | Lookup: `public.tenants` (`smac_master_migration`) |
| 16 | `created_by_id`, `created_by_name`, `created_by_role`, `created_by_email`, `app_name`, `tenant`, `auditable_type`, `entity_type`, `entity_id` | - | `audit_info` | jsonb | - | Additional SAC fields stored in audit_info |

**SMAC columns not migrated:** `archived_at`, `deleted_at`, `entity_id` — no reliable SAC source mapping.

**SAC columns not migrated:** `auditable_type` — used only as filter (`= 'Contract'`), stored in `audit_info`.

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
