# Table Mapping: bank_details (distinct rows) → bank_branches

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: bank_details (distinct rows)
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: bank_branches
- **Source Script**: `04-migration-scripts/master/bank_branches_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.bank_details (distinct rows)`
- **New Path**: `smac_master_migration.public.bank_branches`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Bank Details (`bank_details` → `bank_branches`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `COALESCE(uuid, gen_random_uuid())`
- `parent_id` mapped from `country_id` via `countries_id_mapping`
- Filter: `ifsc_code` and `branch_name` both non-empty; `DISTINCT ON (ifsc_code, branch_name)`
- Target has no `status`/`workflow_status` columns

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE public.bank_branches` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `state_id_mapping` | Get current target row count | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `country_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `state_id_mapping`

- **Purpose**: Get current target row count
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=states

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'states'
  AND target_db = current_database();
```

### `country_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid` | uuid | `id` | uuid | `COALESCE(uuid, gen_random_uuid())` | Preserves SAC uuid when available |
| 2 | `ifsc_code` | text | `code` | text | `TRIM(ifsc_code)` | NOT NULL in SMAC |
| 3 | `branch_name` | text | `name` | text | `INITCAP(TRIM(branch_name))` | NOT NULL in SMAC |
| 4 | `bank_name, address, contact` | text, text, text | `description` | text | `CONCAT_WS(', ', bank_name, address, contact)` | Combined description |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` | No level in SAC |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `country_id` | bigint | `parent_id` | uuid | Map via `country_id_mapping` (`migration.table_mappings` where `target_table = 'countries'`) | Country FK as parent |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 10 | `updated_at, created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 12 | `uuid, ifsc_code, branch_name, bank_name, address, contact, state_id, country_id` | uuid, text, text, text, text, text, bigint, bigint | `audit_info` | jsonb | `jsonb_build_object()` with legacy metadata fields | Includes `legacy_ifsc_code`, `legacy_branch_name`, etc. |

**SAC columns not migrated:** `state_id` — stored in `audit_info` only, not as FK.

**SMAC columns not migrated:** `status`, `workflow_status`, `defined_by`, `archived_at`, `tags` — not on target table.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. State ID Mapping
**Purpose**: Get current target row count
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='states'`

```sql
CREATE TEMP TABLE state_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'states'
  AND target_db = current_database();
```

### 2. Country ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/bank_branches_migration.sql`

## Validation

- Run `05-validation/master/bank_branches_validation.sql` if available
- Run `06-rollback/master/bank_branches_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
