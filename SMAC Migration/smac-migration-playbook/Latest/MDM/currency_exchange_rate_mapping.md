# Table Mapping: exchange_rates → currency_exchange_rate

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: exchange_rates
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: currency_exchange_rate
- **Source Script**: `04-migration-scripts/master/currency_exchange_rate_migration.sql`

- **Legacy Path**: `synergy_master.public.exchange_rates`
- **New Path**: `smac_master_migration.public.currency_exchange_rate`

## Business Key

- **Composite Key**: (`from_currency_id`, `to_currency_id`, `effective_from_date`)
- **Source (orchestration)**: Exchange Rates (`exchange_rates` → `currency_exchange_rate`)

## Migration Notes

- SAC `id` (uuid) preserved directly as SMAC `id`
- `from_currency_id`/`to_currency_id` mapped from 3-char codes via `currency_code_to_uuid_mapping`
- Date columns cast from `date` to `timestamp`
- Pre-migration duplicate UUID check on SAC `id`
- Post-migration UPDATE sets `currencies.currency_rate_available = true`
- Requires `currencies` migrated first


## Special Considerations

- Maps from_currency and to_currency (codes) to UUIDs via migration.table_mappings for currencies
- Preserves legacy UUID from source id column (exchange_rates.id → currency_exchange_rate.id)
- Script performs `TRUNCATE TABLE public.currency_exchange_rate` before insert (full table reload).
- Orchestration dependencies: `currencies`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `currency_code_to_uuid_mapping` | FK lookup | `currency_code`, `currency_uuid` | `migration.table_mappings` (see SQL) | - |

### `currency_code_to_uuid_mapping`

- **Output columns**: currency_code, currency_uuid
- **migration.table_mappings**: target_table=currencies

```sql
CREATE TEMP TABLE currency_code_to_uuid_mapping AS
SELECT
    c.code as currency_code,
    tm.target_id as currency_uuid
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | Direct copy — SAC UUID preserved | No `resolve_target_id` |
| 2 | `from_currency` | character varying(3) | `from_currency_id` | uuid | Map via `currency_code_to_uuid_mapping`; fallback empty GUID | Lookup: `public.currencies` by code |
| 3 | `to_currency` | character varying(3) | `to_currency_id` | uuid | Map via `currency_code_to_uuid_mapping`; fallback empty GUID | Lookup: `public.currencies` by code |
| 4 | `effective_from_date` | date | `effective_from_date` | timestamp without time zone | Cast `date` -> `timestamp` | |
| 5 | `effective_to_date` | date | `effective_to_date` | timestamp without time zone | Cast `date` -> `timestamp` | Nullable |
| 6 | `rate` | numeric(18,6) | `rate` | numeric | Direct copy | |
| 7 | — | — | `source` | text | `NULL` | Not in SAC |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 9 | — | — | `parent_id` | uuid | `NULL` | Not in SAC |
| 10 | — | — | `level` | numeric | Hardcoded `0` | |
| 11 | — | — | `version` | integer | Hardcoded `1` | |
| 12 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 13 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 14 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC has no status |
| 15 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 16 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 17 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC |
| 18 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all NULL | No audit columns in SAC |
| 20 | — | — | `tags` | text[] | `NULL` | Not populated |

**Post-migration changes:** UPDATE `currencies.currency_rate_available = true` for referenced currencies.


## Foreign Key Dependencies

### Prerequisites (from source script)

- `currencies`
- `public.currencies`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Currency Code To Uuid ID Mapping
**Output columns**: `currency_code, currency_uuid`
**migration.table_mappings**: `target_table='currencies'`

```sql
CREATE TEMP TABLE currency_code_to_uuid_mapping AS
SELECT
    c.code as currency_code,
    tm.target_id as currency_uuid
FROM migration.table_mappings tm
JOIN public.currencies c ON c.id = tm.target_id
WHERE tm.target_table = 'currencies'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/currency_exchange_rate_migration.sql`

## Validation

- Run `05-validation/master/currency_exchange_rate_validation.sql` if available
- Run `06-rollback/master/currency_exchange_rate_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
