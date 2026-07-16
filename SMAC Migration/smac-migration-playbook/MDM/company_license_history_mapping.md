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

- Requires companies table to be migrated first
- Migrates rps_company_details to company_license_history. Preserves UUID id. Maps ship_management_company_id to company_id via companies table. Builds license_info JSON from license_number and license_validity_date. Sets level=0, parent_id=NULL. Requires companies table to be migrated first.

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rps_company_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | derived | - | company_rev_id | - | company_map.company_id as company_rev_id | company_map.company_id |
| 3 | derived | - | company_id | - | company_map.company_id | company_map.company_id |
| 4 | license_number, license_validity_date | - | license_info | - | jsonb_build_object( 'LicenseNumber', COALESCE(NULLIF(TRIM(legacy_data.license_number), ''), NULL), 'LicenseExpiryDate', CASE WHEN legacy_data.license_validity_date IS NOT NULL T... | jsonb_build_object( 'LicenseNumber', COALESCE(NULLIF(TRIM(legacy_data.license_number), ''), NULL), 'LicenseExpiryDate', CASE WHEN legacy_data.license_validity_date IS NOT NULL T... |
| 5 | license_number, id, ship_management_company_id | - | code | - | generate_meaningful_code() | generate_meaningful_code( COALESCE(NULLIF(TRIM(legacy_data.license_number), ''), 'LICENSE'), legacy_data.id::text || '_' || COALESCE(company_map.company_id::text, legacy_data.sh... |
| 6 | license_number, id | - | name | - | COALESCE(NULLIF(TRIM(legacy_data.license_number), ''), 'License ' || legacy_data.id::text) as name | COALESCE(NULLIF(TRIM(legacy_data.license_number), ''), 'License ' || legacy_data.id::text) |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at | legacy_data.deleted_at |
| 17 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN legac... |

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
