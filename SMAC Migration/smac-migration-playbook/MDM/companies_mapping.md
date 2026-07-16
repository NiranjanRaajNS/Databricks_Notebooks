# Table Mapping: ship_management_companies → companies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ship_management_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: companies
- **Source Script**: `04-migration-scripts/master/companies_migration.sql`

- **Legacy Path**: `synergy_master.public.ship_management_companies`
- **New Path**: `smac_master_migration.public.companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Preserves identifier UUID when available (Project Rule Section 2.1)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Generates code from name if code column is not available in source
- Maps boolean flags to is_* columns
- is_active → status (true=1, false=0) and workflow_status
- mlc_master records are tagged with "mlc_ship_owner"
- mlc_master is in synergy_vessel database, not synergy_master
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Special Considerations

- Script performs `TRUNCATE TABLE public.companies` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `service_type_mapping` | Check for d | `name`, `service_type_id` | - | - |

### `service_type_mapping`

- **Purpose**: Check for d
- **Output columns**: name, service_type_id

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    name,
    id AS service_type_id
FROM public.service_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | source_table, id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( CASE WHEN legacy_data.source_table = 'mlc_master' THEN 'synergy_vessel'::VARCHAR(100) ELSE 'synergy_master'::VARCHAR(100) END, 'public'::VARCHAR(100... |
| 2 | group_company_code, name, id | - | code | - | COALESCE( NULLIF(TRIM(legacy_data.group_company_code), ''), UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')), 'COMPANY_' || legacy_data.id::text ) as code | COALESCE( NULLIF(TRIM(legacy_data.group_company_code), ''), UPPER(REPLACE(LEFT(TRIM(legacy_data.name), 15), ' ', '_')), 'COMPANY_' || legacy_data.id::text ) |
| 3 | name, id | - | name | - | COALESCE(NULLIF(TRIM(legacy_data.name), ''), 'COMPANY_' || legacy_data.id::text) as name | COALESCE(NULLIF(TRIM(legacy_data.name), ''), 'COMPANY_' || legacy_data.id::text) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | company_type_id | - | (SELECT id FROM public.company_types WHERE LOWER(TRIM(name)) = LOWER('Ship Management Companies') LIMIT 1) as company_type_id | (SELECT id FROM public.company_types WHERE LOWER(TRIM(name)) = LOWER('Ship Management Companies') LIMIT 1) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | synergy_company | - | is_inhouse_company | - | COALESCE(legacy_data.synergy_company, false) as is_inhouse_company | COALESCE(legacy_data.synergy_company, false) |
| 10 | derived | - | level | - | 0 as level | 0 |
| 11 | source_table | - | tags | - | CASE WHEN legacy_data.source_table = 'mlc_master' THEN ARRAY['mlc_ship_owner']::text[] ELSE NULL::text[] END as tags | CASE WHEN legacy_data.source_table = 'mlc_master' THEN ARRAY['mlc_ship_owner']::text[] ELSE NULL::text[] END |
| 12 | deleted_at, source_table, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.source_table = 'mlc_master' AND legacy_data.is_active = false THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.source_table = 'mlc_master' AND legacy_data.is_active = false THEN 3 ELSE 0 END |
| 13 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 14 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 15 | imo_number | - | imo_number | - | NULLIF(TRIM(legacy_data.imo_number), '') as imo_number | NULLIF(TRIM(legacy_data.imo_number), '') |
| 16 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 17 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 18 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 19 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 20 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id::text) <> '' THEN TRIM(legacy_data.created_by_id::text) ELSE NULL ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.company_types`
- `public.service_types`
- `service_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Service Type ID Mapping
**Purpose**: Check for d
**Output columns**: `name, service_type_id`

```sql
CREATE TEMP TABLE service_type_mapping AS
SELECT
    name,
    id AS service_type_id
FROM public.service_types;
```

Full migration context: `04-migration-scripts/master/companies_migration.sql`

## Validation

- Run `05-validation/master/companies_validation.sql` if available
- Run `06-rollback/master/companies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
