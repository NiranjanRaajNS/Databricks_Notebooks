# Table Mapping: family_details → seafarer_family_members

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: family_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_family_members
- **Source Script**: `04-migration-scripts/crewing/seafarer_family_members_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.family_details`
- **New Path**: `smac_crewing_migration.public.seafarer_family_members`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Family Members (`family_details` → `seafarer_family_members`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates family_details to seafarer_family_members table. Preserves legacy identifier UUID when available. Maps seafarer_id (bigint) to uuid via migration.table_mappings. Maps gender_id and relation_id (bigint) to uuid via migration.table_mappings with fallbacks. Requires seafarers table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_family_members` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relation_id_mapping` | FK lookup | `legacy_id::bigint`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `gender_id_mapping` | FK lookup | `legacy_id::integer`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `nationality_id_mapping` | FK lookup | `legacy_id::text`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `relation_id_mapping`

- **Output columns**: legacy_id::bigint, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE relation_id_mapping AS
SELECT legacy_id::bigint, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''family_relations'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### `gender_id_mapping`

- **Output columns**: legacy_id::integer, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT legacy_id::integer, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### `nationality_id_mapping`

- **Output columns**: legacy_id::text, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT legacy_id::text, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'family_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | derived | - | seafarer_id | - | seafarer_id_mapping.target_id as seafarer_id | seafarer_id_mapping.target_id |
| 3 | first_name | - | first_name | - | TRIM(legacy_data.first_name) as first_name | TRIM(legacy_data.first_name) |
| 4 | derived | - | middle_name | - | NULL as middle_name | NULL |
| 5 | last_name | - | last_name | - | TRIM(legacy_data.last_name) as last_name | TRIM(legacy_data.last_name) |
| 6 | derived | - | gender_id | - | gender_id_mapping.new_id as gender_id | gender_id_mapping.new_id |
| 7 | date_of_birth | - | date_of_birth | - | legacy_data.date_of_birth::date as date_of_birth | legacy_data.date_of_birth::date |
| 8 | derived | - | nationality_id | - | nationality_id_mapping.new_id as nationality_id | nationality_id_mapping.new_id |
| 9 | derived | - | relation_id | - | COALESCE( relation_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) as relation_id | COALESCE( relation_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 10 | is_dependent | - | is_dependent | - | COALESCE(legacy_data.is_dependent, false) as is_dependent | COALESCE(legacy_data.is_dependent, false) |
| 11 | is_nok | - | is_next_of_kin | - | COALESCE(legacy_data.is_nok, false) as is_next_of_kin | COALESCE(legacy_data.is_nok, false) |
| 12 | is_ice | - | is_emergency_contact | - | COALESCE(legacy_data.is_ice, false) as is_emergency_contact | COALESCE(legacy_data.is_ice, false) |
| 13 | derived | - | dependency_notes | - | NULL as dependency_notes | NULL |
| 14 | passport_number | - | passport_number | - | TRIM(legacy_data.passport_number) as passport_number | TRIM(legacy_data.passport_number) |
| 15 | date_of_issue | - | passport_issue_date | - | legacy_data.date_of_issue::date as passport_issue_date | legacy_data.date_of_issue::date |
| 16 | expiry_date | - | passport_expiry_date | - | legacy_data.expiry_date::date as passport_expiry_date | legacy_data.expiry_date::date |
| 17 | place_of_issue | - | passport_place_of_issue | - | TRIM(legacy_data.place_of_issue) as passport_place_of_issue | TRIM(legacy_data.place_of_issue) |
| 18 | contact | - | contact_number | - | TRIM(legacy_data.contact) as contact_number | TRIM(legacy_data.contact) |
| 19 | derived | - | email | - | NULL as email | NULL |
| 20 | address | - | address | - | TRIM(legacy_data.address) as address | TRIM(legacy_data.address) |
| 21 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 22 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 23 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 24 | - | - | archived_at | - | NULL | NULL::timestamp |
| 25 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 26 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relation ID Mapping
**Output columns**: `legacy_id::bigint, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE relation_id_mapping AS
SELECT legacy_id::bigint, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''family_relations'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### 2. Gender ID Mapping
**Output columns**: `legacy_id::integer, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT legacy_id::integer, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### 3. Nationality ID Mapping
**Output columns**: `legacy_id::text, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT legacy_id::text, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_family_members_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_family_members_validation.sql` if available
- Run `06-rollback/crewing/seafarer_family_members_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
