# Table Mapping: rps_company_details → company_license_history

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rps_company_details
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: company_license_history
- **Source Script**: `04-migration-scripts/master/company_license_history_migration.sql`

- **Legacy Path**: `synergy_master.public.rps_company_details`
- **New Path**: `smac_master_migration.public.company_license_history`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company License History (`rps_company_details` → `company_license_history`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `company_id`/`company_rev_id` from `ship_management_company_id` via `company_id_mapping`
- `license_info` JSONB from `license_number` + `license_validity_date`
- Requires `companies` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.company_license_history` before insert (full table reload).
- Orchestration dependencies: `companies`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | Check | `legacy_company_id`, `company_id` | - | `synergy_master` |

### `company_id_mapping`

- **Purpose**: Check
- **Output columns**: legacy_company_id, company_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT
    smc.id AS legacy_company_id,
    c.id AS company_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ship_management_companies WHERE identifier IS NOT NULL'
) AS smc(
    id bigint,
    identifier uuid
)
INNER JOIN public.companies c ON c.id = smc.identifier
WHERE smc.identifier IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `ship_management_company_id` | bigint | `company_rev_id` | uuid | Map via `company_id_mapping` | Same as company_id |
| 3 | `ship_management_company_id` | bigint | `company_id` | uuid | Map via `company_id_mapping` | FK: companies |
| 4 | `license_number, license_validity_date` | text, timestamp without time zone | `license_info` | jsonb | `jsonb_build_object('LicenseNumber', ..., 'LicenseExpiryDate', ...)` | Structured license data |
| 5 | `license_number, id, ship_management_company_id` | text, uuid, bigint | `code` | text | `generate_meaningful_code(license_number, composite key)` | Generated code |
| 6 | `license_number, id` | text, uuid | `name` | text | `COALESCE(TRIM(license_number), 'License ' || id::text)` | Display name |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 10 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 13 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at, created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` |  |
| 16 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 17 | `created_by, updated_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` — legacy IDs in notes |  |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Purpose**: Check
**Output columns**: `legacy_company_id, company_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT DISTINCT
    smc.id AS legacy_company_id,
    c.id AS company_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ship_management_companies WHERE identifier IS NOT NULL'
) AS smc(
    id bigint,
    identifier uuid
)
INNER JOIN public.companies c ON c.id = smc.identifier
WHERE smc.identifier IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/company_license_history_migration.sql`

## Validation

- Run `05-validation/master/company_license_history_validation.sql` if available
- Run `06-rollback/master/company_license_history_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
