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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

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
| 1 | id | - | id | - | legacy_data.id as id | legacy_data.id |
| 2 | derived | - | from_currency_id | - | COALESCE( from_curr_mapping.currency_uuid, '00000000-0000-0000-0000-000000000000'::uuid ) as | COALESCE( from_curr_mapping.currency_uuid, '00000000-0000-0000-0000-000000000000'::uuid ) as |
| 3 | - | - | to_currency_id | - | See source script | See source script |
| 4 | - | - | effective_from_date | - | See source script | See source script |
| 5 | - | - | effective_to_date | - | See source script | See source script |
| 6 | - | - | rate | - | See source script | See source script |
| 7 | - | - | source | - | See source script | See source script |
| 8 | - | - | tenant_id | - | See source script | See source script |
| 9 | - | - | parent_id | - | See source script | See source script |
| 10 | - | - | level | - | See source script | See source script |
| 11 | - | - | version | - | See source script | See source script |
| 12 | - | - | defined_by | - | See source script | See source script |
| 13 | - | - | workflow_status | - | See source script | See source script |
| 14 | - | - | status | - | See source script | See source script |
| 15 | - | - | created_at | - | See source script | See source script |
| 16 | - | - | updated_at | - | See source script | See source script |
| 17 | - | - | deleted_at | - | See source script | See source script |
| 18 | - | - | archived_at | - | See source script | See source script |
| 19 | - | - | audit_info | - | See source script | See source script |
| 20 | - | - | tags | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

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
