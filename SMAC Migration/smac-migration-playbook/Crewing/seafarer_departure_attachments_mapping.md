# Table Mapping: seafarer_departures → seafarer_attachments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_departures
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_departure_attachments_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_departures`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departure Attachments (`seafarer_departures` → `seafarer_attachments`)

## Migration Notes

- Migrates attachment-related records from seafarer_departures to seafarer_attachments
- Each departure record becomes an attachment record with file_type = 'Departure'
- Migrates attachment-related records from seafarer_departures to seafarer_attachments. Each departure record with file information becomes an attachment record. Generates new UUID for seafarer_attachments.id. Maps seafarer_id (bigint) to uuid via migration.table_mappings. Sets file_type as 'Departure'. Maps reference_id to migrated seafarer_departures.id (uuid). Uses shore user file fields (file_name, file_content_type, file_url, file_size). Maps seafarer_signed_at to valid_from and shore_user_signed_at to valid_until (cast to date). Requires seafarers and seafarer_departures tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_departures`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `departure_id_mapping` | C | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `departure_id_mapping`

- **Purpose**: C
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_departures

```sql
CREATE TEMP TABLE departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_departures'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | file_name | - | file_name | - | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), '') as file_name | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), '') |
| 4 | file_content_type | - | file_type | - | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 1) ELSE NULL END as fi... | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 1) ELSE NULL END |
| 5 | file_content_type | - | file_sub_type | - | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 2) ELSE NULL END as fi... | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 2) ELSE NULL END |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | file_content_type | - | file_content_type | - | NULLIF(TRIM(legacy_data.file_content_type), '') as file_content_type | NULLIF(TRIM(legacy_data.file_content_type), '') |
| 8 | file_size | - | file_size | - | COALESCE(legacy_data.file_size::bigint, 0) as file_size | COALESCE(legacy_data.file_size::bigint, 0) |
| 9 | file_url | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.file_url), ''), '') as file_url | COALESCE(NULLIF(TRIM(legacy_data.file_url), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'predeparture_checklist'::text as reference_entity | 'predeparture_checklist'::text |
| 12 | derived | - | reference_id | - | departure_id_mapping.new_id as reference_id | departure_id_mapping.new_id |
| 13 | derived | - | version_number | - | 1 as version_number | 1 |
| 14 | - | - | valid_from | - | NULL | NULL::date as valid_ |
| 15 | - | - | valid_until | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | tenant_id | - | See source script | See source script |
| 18 | - | - | created_at | - | See source script | See source script |
| 19 | - | - | updated_at | - | See source script | See source script |
| 20 | - | - | archived_at | - | See source script | See source script |
| 21 | - | - | deleted_at | - | See source script | See source script |
| 22 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_departures`
- `seafarers`
- `shore.seafarer_departures`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Departure ID Mapping
**Purpose**: C
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_departures'`

```sql
CREATE TEMP TABLE departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_departure_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departure_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departure_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
