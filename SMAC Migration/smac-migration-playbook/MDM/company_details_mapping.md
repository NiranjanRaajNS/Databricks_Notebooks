# Table Mapping: ship_management_companies → company_details

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: company_details
- **Source Script**: `04-migration-scripts/master/company_details_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`
- **New Path**: `smac_master_migration.public.company_details`

## Business Key

- **Business Key**: `company_id`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `company_details`)

## Migration Notes

- Requires companies table to be migrated first
- Company details (address, contact info) from ship_management_companies. Requires companies table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.company_details` before insert (full table reload).
- Orchestration dependencies: `companies`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | FK lookup | `legacy_name`, `company_id` | - | - |

### `company_id_mapping`

- **Output columns**: legacy_name, company_id

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    name as legacy_name,
    id as company_id
FROM public.companies;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ship_management_companies'::VARCHAR(100), legacy_data.id::text, current_database()::text::V... |
| 2 | company_id | - | company_id | - | legacy_data.company_id | legacy_data.company_id |
| 3 | address, city, zipcode | - | address | - | CASE WHEN legacy_data.address IS NOT NULL AND TRIM(legacy_data.address) <> '' THEN jsonb_build_object( 'city', NULLIF(TRIM(legacy_data.city), ''), 'state', NULL, 'region', NULL,... | CASE WHEN legacy_data.address IS NOT NULL AND TRIM(legacy_data.address) <> '' THEN jsonb_build_object( 'city', NULLIF(TRIM(legacy_data.city), ''), 'state', NULL, 'region', NULL,... |
| 4 | derived | - | country_id | - | NULL as country_id | NULL |
| 5 | contact_number | - | phone_number | - | NULLIF(TRIM(legacy_data.contact_number), '') as phone_number | NULLIF(TRIM(legacy_data.contact_number), '') |
| 6 | derived | - | email | - | NULL as email | NULL |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 9 | derived | - | version | - | COALESCE( CASE WHEN updated_by_id IS NOT NULL AND updated_by_id ~ '^[0-9]+$' THEN updated_by_id::integer ELSE 1 END, 1 ) as version | COALESCE( CASE WHEN updated_by_id IS NOT NULL AND updated_by_id ~ '^[0-9]+$' THEN updated_by_id::integer ELSE 1 END, 1 ) |
| 10 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 12 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 13 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 14 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id::text) <> '' AND TRIM(legacy_data.created_by_id::text) ~* '^[0-9a-... |
| 15 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 16 | derived | - | tags | - | CASE WHEN doc_company = true THEN ARRAY['doc_company']::text[] ELSE ARRAY[]::text[] END as tags | CASE WHEN doc_company = true THEN ARRAY['doc_company']::text[] ELSE ARRAY[]::text[] END |
| 17 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 18 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 19 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Output columns**: `legacy_name, company_id`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    name as legacy_name,
    id as company_id
FROM public.companies;
```

Full migration context: `04-migration-scripts/master/company_details_migration.sql`

## Validation

- Run `05-validation/master/company_details_validation.sql` if available
- Run `06-rollback/master/company_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
