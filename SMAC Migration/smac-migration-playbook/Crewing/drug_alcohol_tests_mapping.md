# Table Mapping: drug_alcohol_tests → drug_alcohol_tests

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: drug_alcohol_tests
- **Source Script**: `04-migration-scripts/crewing/drug_alcohol_tests_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Drug Alcohol Test Details (`drug_alcohol_test_details` → `drug_alcohol_tests`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates drug_alcohol_test_details to drug_alcohol_tests table. Preserves legacy UUID for id column. Maps seafarer_id (uuid) via migration.table_mappings from smac_crewing_migration. Maps test_type_id (uuid) via migration.table_mappings from smac_master_migration. Maps vessel_id, vessel_category_id, port_id (bigint to uuid) via migration.table_mappings from smac_master_migration (optional). Converts date_of_test from timestamp to date. Converts vessel_imo from bigint to varchar. Sets defaults for new required fields: program_type_id (UUID), workflow_status_id (UUID), status ('Active'), tenant_id. Preserves port_info in audit_info (not in target table). Handles NULL values: seafarer_id and test_type_id generate UUID if mapping not found.

## Special Considerations

- Maps test_type_id from smac_master_migration, vessel_id/vessel_category_id/port_id from smac_master_migration
- Script performs `TRUNCATE TABLE public.drug_alcohol_tests` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `drug_alcohol_test_types`, `vessels`, `vessel_categories`, `ports`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check for duplicate UUIDs in source table | `seafarer_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `test_types_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ports_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarers_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: seafarer_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `test_types_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE test_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''drug_alcohol_test_types'''
) AS t(source_id text, target_id uuid);
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid);
```

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
) AS t(source_id text, target_id uuid);
```

### `ports_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'drug_alcohol_test_details'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | date_of_test | - | date_of_test | - | legacy_data.date_of_test::date as date_of_test | legacy_data.date_of_test::date |
| 4 | derived | - | program_type_id | - | (SELECT program_type_id FROM periodic_program_type LIMIT 1) as program_type_id | (SELECT program_type_id FROM periodic_program_type LIMIT 1) |
| 5 | derived | - | test_type_id | - | COALESCE(test_type_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as test_type_id | COALESCE(test_type_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 6 | derived | - | vessel_id | - | vessel_mapping.new_id as vessel_id | vessel_mapping.new_id |
| 7 | derived | - | vessel_category_id | - | vessel_category_mapping.new_id as vessel_category_id | vessel_category_mapping.new_id |
| 8 | vessel_imo | - | vessel_imo | - | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::text, 10)::varchar(10) ELSE NULL END AS vessel_imo | CASE WHEN legacy_data.vessel_imo IS NOT NULL THEN LEFT(legacy_data.vessel_imo::text, 10)::varchar(10) ELSE NULL END |
| 9 | derived | - | port_id | - | port_mapping.new_id as port_id | port_mapping.new_id |
| 10 | - | - | result_notes | - | NULL | NULL::text |
| 11 | derived | - | workflow_status_id | - | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) as workflow_status_id | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) |
| 12 | is_verified | - | is_verified | - | COALESCE(legacy_data.is_verified, false) as is_verified | COALESCE(legacy_data.is_verified, false) |
| 13 | verified_at | - | verified_at | - | legacy_data.verified_at as verified_at | legacy_data.verified_at |
| 14 | audit_info | - | verified_by_id | - | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'verified_by_id' IS NOT NULL THEN (legacy_data.audit_info->>'verified_by_id')::uuid ELSE NULL END as ve... | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'verified_by_id' IS NOT NULL THEN (legacy_data.audit_info->>'verified_by_id')::uuid ELSE NULL END |
| 15 | - | - | verification_notes | - | NULL | NULL::text |
| 16 | remarks | - | remarks | - | legacy_data.remarks as remarks | legacy_data.remarks |
| 17 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 18 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 19 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 20 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 21 | - | - | archived_at | - | NULL | NULL::timestamp |
| 22 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 23 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by_id' IS NOT NULL AND legacy_data.audit_info->>'created_by_id' <>... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `seafarer_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Test Types ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE test_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''drug_alcohol_test_types'''
) AS t(source_id text, target_id uuid);
```

### 3. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid);
```

### 4. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
) AS t(source_id text, target_id uuid);
```

### 5. Ports ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/drug_alcohol_tests_migration.sql`

## Validation

- Run `05-validation/crewing/drug_alcohol_tests_validation.sql` if available
- Run `06-rollback/crewing/drug_alcohol_tests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
