# Table Mapping: ship_management_companies → company_services

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: company_services
- **Source Script**: `04-migration-scripts/master/company_services_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`
- **New Path**: `smac_master_migration.public.company_services`

## Business Key

- **Composite Key**: (`company_id`, `service_type_id`)
- **Source (orchestration)**: Company Services (`ship_management_companies` → `company_services`)

## Migration Notes

- Creates one row per company per service type based on boolean flags
- doc_company = true → service_type = 'Technical'
- recruitment_company = true → service_type = 'Crewing'
- employer_agent = true → service_type = 'Accounting'
- MLC companies (tag: "mlc_ship_owner") → service_type = 'MLC Ship Owner'
- Only migrates rows where doc_company = true OR recruitment_company = true OR employer_agent = true
- MLC companies are identified by tag "mlc_ship_owner" in companies table
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires companies and service_types tables to be migrated first
- Company services from ship_management_companies. Creates one row per company per service type: doc_company=false → Technical service, recruitment_company=false → Crewing service. If both flags are false, creates two rows. Requires companies and service_types tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.company_services` before insert (full table reload).
- Orchestration dependencies: `companies`, `service_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | FK lookup | `legacy_company_id`, `company_id` | `?.?.ship_management_companies` → `?.?.companies` | - |
| `service_type_mapping` | FK lookup | `normalized_name`, `service_type_id` | - | - |

### `company_id_mapping`

- **Output columns**: legacy_company_id, company_id
- **migration.table_mappings**: source_table=ship_management_companies, target_table=companies

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_db = current_database();
```

### `service_type_mapping`

- **Output columns**: normalized_name, service_type_id

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_name,
    id AS service_type_id
FROM public.service_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ship_management_companies'::VARCHAR(100), (legacy_data.id::text || '|doc_company'), current... |
| 2 | derived | - | company_id | - | cm.company_id | cm.company_id |
| 3 | derived | - | service_type_id | - | st_technical.service_type_id | st_technical.service_type_id |
| 4 | created_at | - | start_date | - | COALESCE(legacy_data.created_at, NOW())::timestamp with time zone AS start_date | COALESCE(legacy_data.created_at, NOW())::timestamp with time zone |
| 5 | - | - | end_date | - | NULL | NULL::timestamp with time zone |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp without time zone |
| 13 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id::text) <> '' THEN TRIM(legacy_data.created_by_id::text) ELSE NULL ... |
| 14 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 15 | derived | - | tags | - | ARRAY['doc_company']::text[] AS tags | ARRAY['doc_company']::text[] |
| 16 | code | - | is_global | - | CASE WHEN companies.code = 'SMRSPL' THEN true ELSE false END AS is_global | CASE WHEN companies.code = 'SMRSPL' THEN true ELSE false END |
| 17 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN COALESCE(legacy_data.is_active, true) = true THEN 0 ELSE 2 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN COALESCE(legacy_data.is_active, true) = true THEN 0 ELSE 2 END |
| 18 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 19 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`
- `public.service_types`
- `service_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Output columns**: `legacy_company_id, company_id`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_db = current_database();
```

### 2. Service Type ID Mapping
**Output columns**: `normalized_name, service_type_id`

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS normalized_name,
    id AS service_type_id
FROM public.service_types;
```

Full migration context: `04-migration-scripts/master/company_services_migration.sql`

## Validation

- Run `05-validation/master/company_services_validation.sql` if available
- Run `06-rollback/master/company_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
