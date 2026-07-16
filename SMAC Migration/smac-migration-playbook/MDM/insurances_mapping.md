# Table Mapping: insurances → insurances

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: insurances
- **Source Script**: `04-migration-scripts/master/insurances_migration.sql`

- **Legacy Path**: `synergy_vessel.public.insurance_p_and_i + synergy_vessel.public.insurance_h_m`
- **New Path**: `smac_master_migration.vessel.insurances`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Insurance P And I,insurance H M (`insurance_p_and_i,insurance_h_m` → `insurances`)

## Migration Notes

- Merges two source tables into one target table with insurance type indicator
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Check for duplicate UUIDs in source tables
- Merged from insurance_p_and_i and insurance_h_m tables

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.insurances` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `countries_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'insurance_p_and_i'::VARCHAR(100), legacy_data.identifier::text, current_database()::text::V... |
| 2 | short_name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.short_name), legacy_data.identifier::text) |
| 3 | full_name, identifier | - | name | - | COALESCE(TRIM(legacy_data.full_name), 'INS_P_AND_I_' || RIGHT(REPLACE(legacy_data.identifier::text, '-', ''), 8)) as name | COALESCE(TRIM(legacy_data.full_name), 'INS_P_AND_I_' || RIGHT(REPLACE(legacy_data.identifier::text, '-', ''), 8)) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | address | - | address | - | CASE WHEN legacy_data.address IS NULL THEN NULL ELSE jsonb_build_object('full_address', NULLIF(TRIM(legacy_data.address), '')) END as address | CASE WHEN legacy_data.address IS NULL THEN NULL ELSE jsonb_build_object('full_address', NULLIF(TRIM(legacy_data.address), '')) END |
| 6 | derived | - | country_id | - | country_mapping.new_id as country_id | country_mapping.new_id |
| 7 | derived | - | type | - | 0 as type | 0 |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 16 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/insurances_migration.sql`

## Validation

- Run `05-validation/master/insurances_validation.sql` if available
- Run `06-rollback/master/insurances_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
