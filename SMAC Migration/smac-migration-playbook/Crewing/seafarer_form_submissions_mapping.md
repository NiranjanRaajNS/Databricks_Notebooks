# Table Mapping: seafarer_form_submissions → seafarer_form_submissions

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_form_submissions
- **Source Script**: `04-migration-scripts/crewing/seafarer_form_submissions_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_joining_documents + synergy_seafarer.public.seafarer_documents`
- **New Path**: `smac_crewing_migration.public.seafarer_form_submissions`

## Business Key

- **Composite Key**: (`seafarer_id`, `form_definitions_id`)
- **Source (orchestration)**: Seafarer Joining Documents (`seafarer_joining_documents` → `seafarer_form_submissions`)

## Migration Notes

- Generate new UUID for id
- Join seafarer_joining_documents and seafarer_documents on seafarer_doc_id
- Map seafarer_id (bigint/uuid) → seafarer_id (uuid) via migration.table_mappings
- Uses standardized SMAC audit_info structure
- Joins seafarer_joining_documents and seafarer_documents on seafarer_doc_id. Extracts submission_data from seafarer_documents.form_response JSONB. Maps seafarer_id via migration.table_mappings (try seafarer_uuid first, then seafarer_id). Maps is_confirmed to is_verified, verified_date to verified_at. Uses standardized SMAC audit_info structure. Only migrates records where form_response IS NOT NULL AND form_response::text <> '{}'.

## Special Considerations

- Extract submission_data from seafarer_documents.form_response JSONB
- Use DISTINCT ON to prevent duplicate mappings
- Script performs `TRUNCATE TABLE public.seafarer_form_submissions` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_uuid_mapping` | FK lookup | `legacy_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `seafarer_uuid_mapping`

- **Output columns**: legacy_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT source_id::uuid AS legacy_uuid, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_joining_documents'::VARCHAR(100), legacy_join.id::text, current_database()::text... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_uuid_map.new_id, seafarer_id_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_uuid_map.new_id, seafarer_id_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | form_type_id | - | NULL AS form_type_id | NULL |
| 4 | derived | - | form_definitions_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS form_definitions_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 5 | derived | - | submission_data | - | COALESCE( legacy_doc.form_response, '{}'::jsonb ) AS submission_data | COALESCE( legacy_doc.form_response, '{}'::jsonb ) |
| 6 | derived | - | form_version | - | 1 AS form_version | 1 |
| 7 | derived | - | workflow_status_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS workflow_status_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 8 | derived | - | is_verified | - | COALESCE(legacy_doc.is_confirmed, false) AS is_verified | COALESCE(legacy_doc.is_confirmed, false) |
| 9 | derived | - | verified_at | - | legacy_doc.verified_date AS verified_at | legacy_doc.verified_date |
| 10 | derived | - | verified_by_id | - | CASE WHEN legacy_doc.verified_by_id IS NOT NULL AND legacy_doc.verified_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_doc.verified_by_id::... | CASE WHEN legacy_doc.verified_by_id IS NOT NULL AND legacy_doc.verified_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_doc.verified_by_id::... |
| 11 | derived | - | verification_notes | - | COALESCE(legacy_doc.approval_comment, legacy_doc.deviate_note) AS verification_notes | COALESCE(legacy_doc.approval_comment, legacy_doc.deviate_note) |
| 12 | derived | - | "Status" | - | CASE WHEN COALESCE(legacy_join.deleted_at, legacy_doc.deleted_at) IS NOT NULL THEN 3 ELSE 0 END AS "Status" | CASE WHEN COALESCE(legacy_join.deleted_at, legacy_doc.deleted_at) IS NOT NULL THEN 3 ELSE 0 END AS "Status" |
| 13 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 14 | derived | - | created_at | - | COALESCE(legacy_join.created_at, legacy_doc.created_at, NOW()) AS created_at | COALESCE(legacy_join.created_at, legacy_doc.created_at, NOW()) |
| 15 | derived | - | updated_at | - | COALESCE(legacy_join.updated_at, legacy_doc.updated_at, legacy_join.created_at, legacy_doc.created_at, NOW()) AS updated_at | COALESCE(legacy_join.updated_at, legacy_doc.updated_at, legacy_join.created_at, legacy_doc.created_at, NOW()) |
| 16 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 17 | derived | - | deleted_at | - | COALESCE(legacy_join.deleted_at, legacy_doc.deleted_at) AS deleted_at | COALESCE(legacy_join.deleted_at, legacy_doc.deleted_at) |
| 18 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_join.created_by_id IS NOT NULL AND legacy_join.created_by_id::text <> '' THEN legacy_join.created_by_id::text WHEN legacy_doc.create... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Seafarer Uuid ID Mapping
**Output columns**: `legacy_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT source_id::uuid AS legacy_uuid, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_form_submissions_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_form_submissions_validation.sql` if available
- Run `06-rollback/crewing/seafarer_form_submissions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
