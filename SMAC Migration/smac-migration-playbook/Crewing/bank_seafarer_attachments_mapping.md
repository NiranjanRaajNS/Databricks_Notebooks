# Table Mapping: bank_seafarer_attachments → bank_seafarer_attachments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: bank_seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/bank_seafarer_attachments_migration.sql`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Bank Seafarer Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates bank-related attachments from seafarer_attachments (filtered by entity_type = 'BankDetail') to seafarer_attachments table. Preserves legacy UUID when available. Maps seafarer_uuid (varchar) to seafarer_id (uuid) via seafarers table. Maps entity_uuid to reference_id via seafarer_bank_accounts table. Sets reference_entity to 'SeafarerBankAccount'. Sets file_type based on URL extension or document_type. Derives status from deleted_at (ACTIVE/DELETED). Only migrates records where entity_type = 'BankDetail' and entity_uuid IS NOT NULL. Requires seafarers and seafarer_bank_accounts tables to be migrated first.

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_bank_accounts`

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
| 4 | url, document_type | - | file_type | - | CASE WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%pdf%' THEN 'application/pdf' WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%jpg%' THE... | CASE WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%pdf%' THEN 'application/pdf' WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%jpg%' THE... |
| 5 | entity_type | - | file_sub_type | - | COALESCE(NULLIF(TRIM(legacy_data.entity_type), ''), '') as file_sub_type | COALESCE(NULLIF(TRIM(legacy_data.entity_type), ''), '') |
| 6 | - | - | master_document_id | - | NULL | NULL::uuid |
| 7 | url, file_content_type | - | file_content_type | - | CASE WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%png%' THEN 'image/png' ELSE NULLIF(TRIM(legacy_data.file_content_type), '') END as file_content_type | CASE WHEN legacy_data.url IS NOT NULL AND LOWER(legacy_data.url) LIKE '%png%' THEN 'image/png' ELSE NULLIF(TRIM(legacy_data.file_content_type), '') END |
| 8 | file_size | - | file_size | - | COALESCE(legacy_data.file_size::bigint, 0) as file_size | COALESCE(legacy_data.file_size::bigint, 0) |
| 9 | url | - | file_url | - | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') as file_url | COALESCE(NULLIF(TRIM(legacy_data.url), ''), '') |
| 10 | - | - | checksum | - | NULL | NULL::text |
| 11 | derived | - | reference_entity | - | 'seafarer_bank_accounts' as reference_entity | 'seafarer_bank_accounts' |
| 12 | derived | - | reference_id | - | sa_appraisal.id as reference_id | sa_appraisal.id |
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
- `seafarers`

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

Full migration context: `04-migration-scripts/crewing/bank_seafarer_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/bank_seafarer_attachments_validation.sql` if available
- Run `06-rollback/crewing/bank_seafarer_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
