# Table Mapping: vessel_owners → vessel_owners

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: vessel_owners
- **Source Script**: `04-migration-scripts/master/vessel_owners_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Owners (`vessel_owners` → `owners`)

## Migration Notes

- Migrates vessel_owners with owner_type_id = GRP (Group Owner)
- Migrates vessel_registered_owners with owner_type_id = REG (Registered Owner)
- Migrates vessel_bare_boat_owner with owner_type_id = BBT (Bare Boat)
- Migrates vessel_beneficiary_owner with owner_type_id = BEN (Beneficiary)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_owners preserving identifier/uuid UUID as id if available, otherwise generates new UUIDs. Master reference table referenced by vessels table via owner_id.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.owners` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | FK lookup | `legacy_id`, `new_id`, `country_name` | `migration.table_mappings` (see SQL) | - |
| `countries_fallback_mapping` | Get BEN (Beneficiary) UUID from owner_types table | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `countries_id_mapping`

- **Output columns**: legacy_id, new_id, country_name
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### `countries_fallback_mapping`

- **Purpose**: Get BEN (Beneficiary) UUID from owner_types table
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | DISTINCT ON (id) id | DISTINCT ON (id) id |
| 2 | derived | - | code | - | code | code |
| 3 | derived | - | name | - | name | name |
| 4 | derived | - | description | - | description | description |
| 5 | derived | - | contact_number | - | contact_number | contact_number |
| 6 | derived | - | address | - | address | address |
| 7 | derived | - | country_id | - | country_id | country_id |
| 8 | derived | - | tenant_id | - | tenant_id | tenant_id |
| 9 | derived | - | parent_id | - | parent_id | parent_id |
| 10 | derived | - | version | - | version | version |
| 11 | derived | - | created_at | - | created_at | created_at |
| 12 | derived | - | updated_at | - | updated_at | updated_at |
| 13 | derived | - | deleted_at | - | deleted_at | deleted_at |
| 14 | derived | - | archived_at | - | archived_at | archived_at |
| 15 | derived | - | audit_info | - | audit_info | audit_info |
| 16 | derived | - | owner_type_id | - | owner_type_id | owner_type_id |
| 17 | derived | - | level | - | level | level |
| 18 | derived | - | tags | - | tags | tags |
| 19 | derived | - | status | - | status | status |
| 20 | derived | - | workflow_status | - | workflow_status | workflow_status |
| 21 | derived | - | defined_by | - | defined_by | defined_by |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
**Output columns**: `legacy_id, new_id, country_name`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    tm.source_id::text as legacy_id,
    tm.target_id as new_id,
    c.name as country_name
FROM migration.table_mappings tm
INNER JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND c.deleted_at IS NULL;
```

### 2. Countries Fallback ID Mapping
**Purpose**: Get BEN (Beneficiary) UUID from owner_types table
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_fallback_mapping AS
SELECT DISTINCT ON (tm.source_id::text)
    tm.source_id::text as legacy_id,
    active_c.id as new_id
FROM migration.table_mappings tm
INNER JOIN public.countries deleted_c ON deleted_c.id = tm.target_id
INNER JOIN public.countries active_c ON UPPER(TRIM(deleted_c.name)) = UPPER(TRIM(active_c.name))
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database()
  AND deleted_c.deleted_at IS NOT NULL
  AND active_c.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM countries_id_mapping cm
      WHERE cm.legacy_id = tm.source_id::text
  );
```

Full migration context: `04-migration-scripts/master/vessel_owners_migration.sql`

## Validation

- Run `05-validation/master/vessel_owners_validation.sql` if available
- Run `06-rollback/master/vessel_owners_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
