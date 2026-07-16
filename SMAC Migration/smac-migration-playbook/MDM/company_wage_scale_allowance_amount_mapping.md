# Table Mapping: additional_wages → company_wage_scale_allowance_amount

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: additional_wages
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_scale_allowance_amount
- **Source Script**: `04-migration-scripts/master/company_wage_scale_allowance_amount_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.additional_wages`
- **New Path**: `smac_master_migration.crewing.company_wage_scale_allowance_amount`

## Business Key

- **Composite Key**: (`company_wage_scale_allowance_id`, `wage_component_id`)
- **Source (orchestration)**: Company Wage Scale Allowance Amount (`additional_wages` → `company_wage_scale_allowance_amount`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates company_wage_scale_allowance_amount from synergy_crewwage.public.additional_wages. Maps to company_wage_scale_allowances using 1-1 relationship. Sets workflow_status to 1 (PendingApproval). Status and deleted_at set to NULL (not mapped from source).

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_scale_allowance_amount` before insert (full table reload).
- Orchestration dependencies: `company_wage_scale_allowances`, `wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_scale_allowances_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `company_wage_scale_allowances_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_scale_allowances

```sql
CREATE TEMP TABLE company_wage_scale_allowances_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scale_allowances'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'additional_wages'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(... |
| 2 | derived | - | company_wage_scale_allowance_id | - | cwsa_mapping.new_id as company_wage_scale_allowance_id | cwsa_mapping.new_id |
| 3 | derived | - | wage_component_id | - | COALESCE(wc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as wage_component_id | COALESCE(wc_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | min_experience | - | range_start | - | legacy_data.min_experience as range_start | legacy_data.min_experience |
| 5 | max_experience | - | range_end | - | legacy_data.max_experience as range_end | legacy_data.max_experience |
| 6 | amount | - | pay | - | legacy_data.amount as pay | legacy_data.amount |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 9 | derived | - | level | - | 0 as level | 0 |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | isdeleted | - | status | - | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.isdeleted = true THEN 3 ELSE 0 END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.company_wage_scale_allowances`
- `crewing.wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Scale Allowances ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_scale_allowances'`

```sql
CREATE TEMP TABLE company_wage_scale_allowances_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scale_allowances'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_scale_allowance_amount_migration.sql`

## Validation

- Run `05-validation/master/company_wage_scale_allowance_amount_validation.sql` if available
- Run `06-rollback/master/company_wage_scale_allowance_amount_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
