# Table Mapping: reimbursement_sub_categories → reimbursement_sub_categories

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: reimbursement_sub_categories
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: reimbursement_sub_categories
- **Source Script**: `04-migration-scripts/master/reimbursement_sub_categories_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.reimbursement_sub_categories`
- **New Path**: `smac_master_migration.crewing.reimbursement_sub_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Sub Categories (`vessel_sub_categories` → `sub_categories`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_sub_categories preserving identifier UUID as id if available. Target schema is vessel

## Special Considerations

- Requires reimbursement_categories to be migrated first
- Script performs `TRUNCATE TABLE crewing.reimbursement_sub_categories` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `category_id_mapping` | Check for duplicate UUIDs in source table | `category_id`, `category_name_lower`, `reimbursement_type_name` | - | - |

### `category_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: category_id, category_name_lower, reimbursement_type_name

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT ON (category_name_lower)
    id AS category_id,
    category_name_lower,
    reimbursement_type_name
FROM (
    SELECT
        A.id,
        TRIM(LOWER(A.name)) AS category_name_lower,
        1 AS priority,
        B.name AS reimbursement_type_name
    FROM crewing.reimbursement_categories A
    JOIN crewing.reimbursement_types B ON B.id = A.reimbursement_type_id
    WHERE A.name IS NOT NULL AND TRIM(A.name) != ''
) sub
ORDER BY category_name_lower, priority, id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, reimbursement_type | - | id | - | migration.resolve_target_id() | COALESCE( migration.resolve_target_id( 'synergy_crewwage'::VARCHAR(100), 'public'::VARCHAR(100), 'reimbursement_sub_categories'::VARCHAR(100), legacy_data.id::text || '_' || leg... |
| 2 | derived | - | reimbursement_category_id | - | COALESCE(rc.id, '00000000-0000-0000-0000-000000000000'::uuid) as reimbursement_category_id | COALESCE(rc.id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 4 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 5 | name | - | description | - | TRIM(legacy_data.name) as description | TRIM(legacy_data.name) |
| 6 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `reimbursement_categories`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Category ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `category_id, category_name_lower, reimbursement_type_name`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT ON (category_name_lower)
    id AS category_id,
    category_name_lower,
    reimbursement_type_name
FROM (
    SELECT
        A.id,
        TRIM(LOWER(A.name)) AS category_name_lower,
        1 AS priority,
        B.name AS reimbursement_type_name
    FROM crewing.reimbursement_categories A
    JOIN crewing.reimbursement_types B ON B.id = A.reimbursement_type_id
    WHERE A.name IS NOT NULL AND TRIM(A.name) != ''
) sub
ORDER BY category_name_lower, priority, id;
```

Full migration context: `04-migration-scripts/master/reimbursement_sub_categories_migration.sql`

## Validation

- Run `05-validation/master/reimbursement_sub_categories_validation.sql` if available
- Run `06-rollback/master/reimbursement_sub_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
