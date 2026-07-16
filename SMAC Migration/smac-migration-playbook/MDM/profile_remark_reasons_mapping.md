# Table Mapping: profile_remark_reasons → profile_remark_reasons

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: profile_remark_reasons
- **Source Script**: `04-migration-scripts/master/profile_remark_reasons_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Profile Remarks (`seafarer_profile_remarks` → `profile_remark_reasons`)

## Migration Notes

- Extract distinct values from name and description columns in seafarer_profile_remarks table
- Generate new UUIDs for each distinct name/description combination
- Map name and description directly to target table
- Record legacy value → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates distinct values from seafarer_profile_remarks.reason column

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.profile_remark_reasons` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `profile_remark_type_mapping` | Check for duplicate UUIDs in source table (if uuid column exists) | `name_lower`, `code_lower`, `target_id` | - | - |

### `profile_remark_type_mapping`

- **Purpose**: Check for duplicate UUIDs in source table (if uuid column exists)
- **Output columns**: name_lower, code_lower, target_id

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    LOWER(TRIM(code)) AS code_lower,
    id AS target_id
FROM crewing.profile_remark_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | reason_name, legacy_id | - | id | - | migration.resolve_target_id() | DISTINCT ON (LOWER(TRIM(s.reason_name))) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_profile_remarks'::VARCHAR(100), s.legac... |
| 2 | reason_name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(s.reason_name), NULL) |
| 3 | reason_name | - | name | - | LEFT(COALESCE(s.reason_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.reason_name, 'UNKNOWN'), 255) |
| 4 | reason_description | - | description | - | LEFT(COALESCE(s.reason_description, ''), 1000) AS description | LEFT(COALESCE(s.reason_description, ''), 1000) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | level | - | 0 AS level | 0 |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | derived | - | status | - | 0 AS status | 0 |
| 12 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 13 | updated_at, created_at | - | updated_at | - | COALESCE(s.updated_at, s.created_at, NOW()) AS updated_at | COALESCE(s.updated_at, s.created_at, NOW()) |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | reason_description, reason_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN s.rea... |
| 17 | derived | - | tags | - | ARRAY[]::text[] AS tags | ARRAY[]::text[] |
| 18 | reason_type | - | profile_remark_type_id | - | ( SELECT prt.target_id FROM profile_remark_type_mapping prt WHERE TRIM(COALESCE(s.reason_type, '')) <> '' AND ( prt.code_lower = LOWER(TRIM(s.reason_type)) OR prt.name_lower = L... | ( SELECT prt.target_id FROM profile_remark_type_mapping prt WHERE TRIM(COALESCE(s.reason_type, '')) <> '' AND ( prt.code_lower = LOWER(TRIM(s.reason_type)) OR prt.name_lower = L... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Profile Remark Type ID Mapping
**Purpose**: Check for duplicate UUIDs in source table (if uuid column exists)
**Output columns**: `name_lower, code_lower, target_id`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    LOWER(TRIM(code)) AS code_lower,
    id AS target_id
FROM crewing.profile_remark_types;
```

Full migration context: `04-migration-scripts/master/profile_remark_reasons_migration.sql`

## Validation

- Run `05-validation/master/profile_remark_reasons_validation.sql` if available
- Run `06-rollback/master/profile_remark_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
