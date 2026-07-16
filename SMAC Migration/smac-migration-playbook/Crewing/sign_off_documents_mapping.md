# Table Mapping: seafarer_signoff_documents → sign_off_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: sign_off_documents
- **Source Script**: `04-migration-scripts/crewing/sign_off_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_documents`
- **New Path**: `smac_crewing_migration.public.sign_off_documents`

## Business Key

- **Business Key**: `mapper_uuid`
- **Source (orchestration)**: Sign Off Documents (`seafarer_signoff_documents` → `sign_off_documents`)

## Migration Notes

- mapper_uuid may have duplicates in source table, so we use composite key (sign_off_detail_id + master_document_id) as source_id
- Migrates seafarer_signoff_documents to sign_off_documents. Preserves mapper_uuid as id. Maps sign_off_detail_id to sign_off_id via signoff_details mapping. Maps master_document_id to seafarer_document_id (direct UUID). Skips records where mapper_uuid IS NULL.

## Special Considerations

- Script performs `TRUNCATE TABLE public.sign_off_documents` before insert (full table reload).
- Orchestration dependencies: `signoff_details`, `seafarer_documents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `signoff_id_mapping` | FK lookup | `legacy_signoff_detail_id`, `sign_off_id` | `migration.table_mappings` (see SQL) | - |

### `signoff_id_mapping`

- **Output columns**: legacy_signoff_detail_id, sign_off_id
- **migration.table_mappings**: target_table=sign_off_details

```sql
CREATE TEMP TABLE signoff_id_mapping AS
SELECT
    source_id::bigint AS legacy_signoff_detail_id,
    target_id AS sign_off_id
FROM migration.table_mappings
WHERE target_table = 'sign_off_details'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_signoff_documents'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | sign_off_id | - | signoff_map.sign_off_id | signoff_map.sign_off_id |
| 3 | master_document_id | - | seafarer_document_id | - | legacy_data.master_document_id AS seafarer_document_id | legacy_data.master_document_id |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 6 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 7 | - | - | archived_at | - | NULL | NULL::timestamp |
| 8 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 9 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text ELSE 'Active'::text END |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Signoff ID Mapping
**Output columns**: `legacy_signoff_detail_id, sign_off_id`
**migration.table_mappings**: `target_table='sign_off_details'`

```sql
CREATE TEMP TABLE signoff_id_mapping AS
SELECT
    source_id::bigint AS legacy_signoff_detail_id,
    target_id AS sign_off_id
FROM migration.table_mappings
WHERE target_table = 'sign_off_details'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/sign_off_documents_migration.sql`

## Validation

- Run `05-validation/crewing/sign_off_documents_validation.sql` if available
- Run `06-rollback/crewing/sign_off_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
