# Table Mapping: seafarer_attachments → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_debrief_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_attachments`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debrief Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Migrates only attachments where entity_type = 'Appraisal_Debrief'
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_attachments table where entity_type = 'Appraisal_Debrief'. Preserves legacy uuid UUID when available. Maps seafarer_id via seafarers table. Maps reference_id to seafarer_debriefs.id via entity_uuid. Sets reference_entity to 'SeafarerDebrief'. Sets default values for version_number (1) and status (ACTIVE/DELETED). Requires seafarers and seafarer_debriefs tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_debriefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `target_id`, `seafarer_uuid_text` | - | - |

### `seafarer_uuid_mapping`

- **Output columns**: target_id, seafarer_uuid_text

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_attachments'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_uuid_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_uuid_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | file_name | - | file_name | - | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), '') as file_name | COALESCE(NULLIF(TRIM(legacy_data.file_name), ''), '') |
| 4 | file_content_type | - | file_type | - | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 1) ELSE 'application' ... | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 1) ELSE 'application' END |
| 5 | file_content_type | - | file_sub_type | - | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 2) ELSE NULL END as fi... | CASE WHEN legacy_data.file_content_type IS NOT NULL AND legacy_data.file_content_type LIKE '%/%' THEN SPLIT_PART(TRIM(legacy_data.file_content_type), '/', 2) ELSE NULL END |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | file_content_type | - | file_content_type | - | NULLIF(TRIM(legacy_data.file_content_type), '') as file_content_type | NULLIF(TRIM(legacy_data.file_content_type), '') |
| 8 | file_size | - | file_size | - | COALESCE(legacy_data.file_size::bigint, 0) as file_size | COALESCE(legacy_data.file_size::bigint, 0) |
| 9 | url | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') as file_url | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | entity_type | - | reference_entity | - | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.entity_type, ''))) = 'APPRAISAL_DEBRIEF' THEN 'seafarer_debriefs' END as reference_entity | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.entity_type, ''))) = 'APPRAISAL_DEBRIEF' THEN 'seafarer_debriefs' END |
| 12 | derived | - | reference_id | - | sa_debrief.id as reference_id | sa_debrief.id |
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
- `seafarer_debriefs`
- `seafarers`
- `shore.seafarer_debriefs`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `target_id, seafarer_uuid_text`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

Full migration context: `04-migration-scripts/crewing/seafarer_debrief_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debrief_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debrief_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
