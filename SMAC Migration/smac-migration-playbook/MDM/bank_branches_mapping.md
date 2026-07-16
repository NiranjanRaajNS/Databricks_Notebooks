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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Distinct values from bank_details.branch_name

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
| 1 | - | - | id | - | DISTINCT ON (ifsc_code, branch_name) COALESCE(uuid, gen_random_uuid()) as id | DISTINCT ON (ifsc_code, branch_name) COALESCE(uuid, gen_random_uuid()) |
| 2 | derived | - | code | - | TRIM(ifsc_code) as code | TRIM(ifsc_code) |
| 3 | derived | - | name | - | INITCAP(TRIM(branch_name)) as name | INITCAP(TRIM(branch_name)) |
| 4 | derived | - | description | - | CONCAT_WS(', ', NULLIF(TRIM(bank_name), ''), NULLIF(TRIM(address), ''), NULLIF(TRIM(contact), '') ) as description | CONCAT_WS(', ', NULLIF(TRIM(bank_name), ''), NULLIF(TRIM(address), ''), NULLIF(TRIM(contact), '') ) |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | country_map.new_id as parent_id | country_map.new_id |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 10 | derived | - | updated_at | - | COALESCE(updated_at, created_at, NOW()) as updated_at | COALESCE(updated_at, created_at, NOW()) |
| 11 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 12 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
