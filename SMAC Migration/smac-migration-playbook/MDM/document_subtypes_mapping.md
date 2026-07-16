# Table Mapping: document_subtypes → document_subtypes

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_subtypes
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_subtypes
- **Source Script**: `04-migration-scripts/master/document_subtypes_migration.sql`

- **Legacy Path**: `synergy_master.document.document_subtypes`
- **New Path**: `smac_master_migration.document.document_subtypes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Subtypes (`document_subtypes` → `document_subtypes`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates document_subtypes preserving identifier UUID as id. document_type_id maps to document_types.id via migration.table_mappings. Requires document_types table to be migrated first.

## Special Considerations

- Requires document_types table to be migrated first (for document_type_id mapping)
- Script performs `TRUNCATE TABLE document.document_subtypes` before insert (full table reload).
- Orchestration dependencies: `document_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `document_type_id_mapping` | Check for duplicate UUIDs in source table | `source_id::text`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `document_type_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: source_id::text, target_id
- **migration.table_mappings**: target_table=document_types

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'document'::VARCHAR(100), 'document_subtypes'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | code, name | - | code | - | COALESCE(NULLIF(TRIM(legacy_data.code), ''), LEFT(TRIM(legacy_data.name), 10)) as code | COALESCE(NULLIF(TRIM(legacy_data.code), ''), LEFT(TRIM(legacy_data.name), 10)) |
| 4 | derived | - | document_type_id | - | COALESCE(dtm.target_id, (SELECT target_id FROM migration.table_mappings WHERE target_table = 'document_types' AND target_db = current_database() LIMIT 1)) as document_type_id | COALESCE(dtm.target_id, (SELECT target_id FROM migration.table_mappings WHERE target_table = 'document_types' AND target_db = current_database() LIMIT 1)) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | status | - | status | - | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... | CASE WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'DRAF... |
| 10 | derived | - | level | - | 0 as level | 0 |
| 11 | audit_info | - | created_at | - | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'CreatedAt' AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL AND legacy_data.audit_info->>'CreatedA... | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'CreatedAt' AND legacy_data.audit_info->>'CreatedAt' IS NOT NULL AND legacy_data.audit_info->>'CreatedA... |
| 12 | audit_info | - | updated_at | - | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'UpdatedAt' AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL AND legacy_data.audit_info->>'UpdatedA... | CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info ? 'UpdatedAt' AND legacy_data.audit_info->>'UpdatedAt' IS NOT NULL AND legacy_data.audit_info->>'UpdatedA... |
| 13 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'CreatedBy' IS NOT NULL AND TRIM(legacy_data.audit_info->>'CreatedBy') <> '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.document_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Document Type ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `source_id::text, target_id`
**migration.table_mappings**: `target_table='document_types'`

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/document_subtypes_migration.sql`

## Validation

- Run `05-validation/master/document_subtypes_validation.sql` if available
- Run `06-rollback/master/document_subtypes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
