# Table Mapping: cba_audit_info → cba_audit_info

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: cba_audit_info
- **Source Script**: `04-migration-scripts/master/cba_audit_info_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cba Audit Info (`cba_audit_info` → `cba_audit_info`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates cba_audit_info preserving identifier UUID as id if available

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_audit_info` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cbas_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'cba_audit_info'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | derived | - | description | - | TRIM(description) as description | TRIM(description) |
| 3 | derived | - | action | - | action as action | action |
| 4 | derived | - | cba_id | - | COALESCE(cba_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as cba_id | COALESCE(cba_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | derived | - | changed_by | - | COALESCE(created_by_id::uuid, '00000000-0000-0000-0000-000000000000'::uuid) as changed_by | COALESCE(created_by_id::uuid, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | derived | - | changed_on | - | COALESCE(created_at, NOW()) as changed_on | COALESCE(created_at, NOW()) |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 2 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 2 ELSE 0 END |
| 12 | derived | - | level | - | 0 as level | 0 |
| 13 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 14 | derived | - | updated_at | - | COALESCE(created_at, NOW()) as updated_at | COALESCE(created_at, NOW()) |
| 15 | derived | - | deleted_at | - | deleted_at as deleted_at | deleted_at |
| 16 | created_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::te... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cbas ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cbas'`

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_audit_info_migration.sql`

## Validation

- Run `05-validation/master/cba_audit_info_validation.sql` if available
- Run `06-rollback/master/cba_audit_info_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
