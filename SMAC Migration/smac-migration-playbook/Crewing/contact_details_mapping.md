# Table Mapping: contact_details → contact_details

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: contact_details
- **Source Script**: `04-migration-scripts/crewing/contact_details_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Contact Details (`contact_details` → `contact_details`)

## Migration Notes

- Preserves legacy UUID from source uuid column
- Migrates contact_details to contact_details table. Preserves legacy UUID from source uuid column as target id. Maps seafarer_id (bigint) to uuid via migration.table_mappings from smac_crewing_migration (generates UUID if mapping not found - NOT NULL constraint). Maps contact_type (integer, defaults to 0 if NULL - NOT NULL constraint). Maps phone to phone_number, emergency_contact_number to alternate_phone_number, emergency_contact_person to full_name. Combines address, city, state_id, country_id, pin_code, country_code into address JSONB. Sets is_active to true (NOT NULL), preferred_contact to false. Stores nearest_airport, fax, user_id in audit_info for reference.

## Special Considerations

- Maps seafarer_id via migration.table_mappings, generates UUID if mapping not found (NOT NULL constraint)
- Script performs `TRUNCATE TABLE shared.contact_details` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | uuid, id | - | tenant_id | - | DISTINCT ON ( CASE WHEN legacy_data.uuid IS NULL OR legacy_data.uuid = '00000000-0000-0000-0000-000000000000'::uuid THEN legacy_data.id::text ELSE legacy_data.uuid::text END ) :... | DISTINCT ON ( CASE WHEN legacy_data.uuid IS NULL OR legacy_data.uuid = '00000000-0000-0000-0000-000000000000'::uuid THEN legacy_data.id::text ELSE legacy_data.uuid::text END ) :... |
| 2 | uuid | - | id | - | CASE WHEN legacy_data.uuid IS NULL OR legacy_data.uuid = '00000000-0000-0000-0000-000000000000'::uuid THEN gen_random_uuid() ELSE legacy_data.uuid END as id | CASE WHEN legacy_data.uuid IS NULL OR legacy_data.uuid = '00000000-0000-0000-0000-000000000000'::uuid THEN gen_random_uuid() ELSE legacy_data.uuid END |
| 3 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | contact_type | - | contact_type | - | COALESCE(legacy_data.contact_type, 0) as contact_type | COALESCE(legacy_data.contact_type, 0) |
| 5 | emergency_contact_person | - | full_name | - | CASE WHEN legacy_data.emergency_contact_person IS NOT NULL AND TRIM(legacy_data.emergency_contact_person) != '' THEN TRIM(legacy_data.emergency_contact_person) ELSE NULL END as ... | CASE WHEN legacy_data.emergency_contact_person IS NOT NULL AND TRIM(legacy_data.emergency_contact_person) != '' THEN TRIM(legacy_data.emergency_contact_person) ELSE NULL END |
| 6 | - | - | relationship_to_seafarer | - | NULL | NULL::varchar |
| 7 | email | - | email | - | CASE WHEN legacy_data.email IS NOT NULL AND TRIM(legacy_data.email) != '' THEN TRIM(legacy_data.email) ELSE NULL END as email | CASE WHEN legacy_data.email IS NOT NULL AND TRIM(legacy_data.email) != '' THEN TRIM(legacy_data.email) ELSE NULL END |
| 8 | phone | - | phone_number | - | CASE WHEN legacy_data.phone IS NOT NULL AND TRIM(legacy_data.phone) != '' THEN TRIM(legacy_data.phone) ELSE NULL END as phone_number | CASE WHEN legacy_data.phone IS NOT NULL AND TRIM(legacy_data.phone) != '' THEN TRIM(legacy_data.phone) ELSE NULL END |
| 9 | emergency_contact_number | - | alternate_phone_number | - | CASE WHEN legacy_data.emergency_contact_number IS NOT NULL AND TRIM(legacy_data.emergency_contact_number) != '' THEN TRIM(legacy_data.emergency_contact_number) ELSE NULL END as ... | CASE WHEN legacy_data.emergency_contact_number IS NOT NULL AND TRIM(legacy_data.emergency_contact_number) != '' THEN TRIM(legacy_data.emergency_contact_number) ELSE NULL END |
| 10 | address, city, state_id, country_id, pin_code, country_code | - | address | - | CASE WHEN legacy_data.address IS NOT NULL OR legacy_data.city IS NOT NULL OR legacy_data.state_id IS NOT NULL OR legacy_data.country_id IS NOT NULL OR legacy_data.pin_code IS NO... | CASE WHEN legacy_data.address IS NOT NULL OR legacy_data.city IS NOT NULL OR legacy_data.state_id IS NOT NULL OR legacy_data.country_id IS NOT NULL OR legacy_data.pin_code IS NO... |
| 11 | derived | - | preferred_contact | - | false as preferred_contact | false |
| 12 | derived | - | is_active | - | true as is_active | true |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 17 | created_by_id, updated_by_id, id | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/contact_details_migration.sql`

## Validation

- Run `05-validation/crewing/contact_details_validation.sql` if available
- Run `06-rollback/crewing/contact_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
