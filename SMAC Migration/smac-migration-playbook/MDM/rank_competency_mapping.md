# Table Mapping: ranks → rank_competency_mapping

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ranks
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: rank_competency_mapping
- **Source Script**: `04-migration-scripts/master/rank_competency_mapping_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks`
- **New Path**: `smac_master_migration.public.rank_competency_mapping`

## Migration Notes

- Source: legacy ranks table with certificate_of_competency column
- Map rank_id from legacy rank id (bigint) to new rank UUID via migration.table_mappings
- Map document_id from legacy certificate_of_competency (UUID) to new document UUID via migration.table_mappings
- Generate code from rank name and document name combination
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_competency_mapping` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `documents_id_mapping` | FK lookup | `legacy_document_id`, `new_document_id` | `synergy_master.document.documents` → `?.document.documents` | - |

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

### `documents_id_mapping`

- **Output columns**: legacy_document_id, new_document_id
- **migration.table_mappings**: source_db=synergy_master, source_schema=document, source_table=documents, target_schema=document, target_table=documents

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT
    TRIM(source_id) as legacy_document_id,
    target_id as new_document_id
FROM migration.table_mappings
WHERE source_db = 'synergy_master'
  AND source_schema = 'document'
  AND source_table = 'documents'
  AND target_table = 'documents'
  AND target_schema = 'document'
  AND target_db = current_database()
  AND source_db = 'synergy_master'
  AND source_schema = 'document';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | rank_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'ranks'::VARCHAR(100), legacy_data.rank_id::text || '|' || TRIM(cert_uuid.value), current_da... |
| 2 | rank_name | - | code | - | generate_meaningful_code() | generate_meaningful_code( COALESCE(TRIM(legacy_data.rank_name), ''), NULL ) |
| 3 | derived | - | rank_id | - | rank_map.new_id as rank_id | rank_map.new_id |
| 4 | derived | - | document_id | - | doc_map.new_document_id as document_id | doc_map.new_document_id |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at::timestamp, NOW()::timestamp) as created_at | COALESCE(legacy_data.created_at::timestamp, NOW()::timestamp) |
| 10 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at::timestamp, NOW()::timestamp) as updated_at | COALESCE(legacy_data.updated_at::timestamp, NOW()::timestamp) |
| 11 | deleted_at | - | deleted_at | - | legacy_data.deleted_at::timestamp as deleted_at | legacy_data.deleted_at::timestamp |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | - | - | tags | - | NULL | NULL::text[] |
| 15 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 16 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 17 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

### 2. Documents ID Mapping
**Output columns**: `legacy_document_id, new_document_id`
**migration.table_mappings**: `documents` → `documents` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT
    TRIM(source_id) as legacy_document_id,
    target_id as new_document_id
FROM migration.table_mappings
WHERE source_db = 'synergy_master'
  AND source_schema = 'document'
  AND source_table = 'documents'
  AND target_table = 'documents'
  AND target_schema = 'document'
  AND target_db = current_database()
  AND source_db = 'synergy_master'
  AND source_schema = 'document';
```

Full migration context: `04-migration-scripts/master/rank_competency_mapping_migration.sql`

## Validation

- Run `05-validation/master/rank_competency_mapping_validation.sql` if available
- Run `06-rollback/master/rank_competency_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
