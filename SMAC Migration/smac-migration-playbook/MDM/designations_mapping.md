# Table Mapping: "Designation" → designations

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Designation"
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: designations
- **Source Script**: `04-migration-scripts/master/designations_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Designation"`
- **New Path**: `smac_master_migration.public.designations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Designation (`Designation` → `designations`)

## Migration Notes

- Source table has integer "Id", will use migration.resolve_target_id() for idempotent UUID generation
- Map "DepartmentId" (integer) to department_id (uuid) via migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Source table name is case-sensitive: "Designation" (with quotes)
- No duplicate UUID check needed as source table does not have identifier/uuid column
- Mappings in migration.table_mappings are managed automatically by migration.resolve_target_id()
- Migrated from positions table (same source as positions migration)

## Special Considerations

- Script performs `TRUNCATE TABLE public.designations` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `departments_id_mapping` | Note: No duplicate UUID check needed as source table does not have identifier/uuid column | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `departments_id_mapping`

- **Purpose**: Note: No duplicate UUID check needed as source table does not have identifier/uuid column
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=departments

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_identity_shore_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Designation'::VARCHAR(100), legacy_data."Id"::text, current_database()::text::... |
| 2 | derived | - | name | - | TRIM(legacy_data."Name") as name | TRIM(legacy_data."Name") |
| 3 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data."Name"), NULL) |
| 4 | derived | - | description | - | NULLIF(TRIM(legacy_data."Description"), '') as description | NULLIF(TRIM(legacy_data."Description"), '') |
| 5 | derived | - | department_id | - | COALESCE(dept_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) AS department_id | COALESCE(dept_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 12 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 13 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 14 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 15 | derived | - | level | - | 0::numeric AS level | 0::numeric |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Departments ID Mapping
**Purpose**: Note: No duplicate UUID check needed as source table does not have identifier/uuid column
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='departments'`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/designations_migration.sql`

## Validation

- Run `05-validation/master/designations_validation.sql` if available
- Run `06-rollback/master/designations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
