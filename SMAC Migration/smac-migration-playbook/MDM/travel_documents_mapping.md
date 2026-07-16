# Table Mapping: travel_document_lists → travel_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: travel_document_lists
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: travel_documents
- **Source Script**: `04-migration-scripts/master/travel_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.travel_document_lists`
- **New Path**: `smac_master_migration.document.travel_documents`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Travel Documents (`travel_document_lists` → `travel_documents`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates travel_document_lists to travel_documents preserving UUID as id. Maps identifier to code (or generates from name), name to document_name, mandatory_for > 0 to is_required boolean, is_linked_with_seafarer_document to is_compliant_check_required. Maps status based on deleted_at (Case 1 pattern). Uses standardized SMAC audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE document.travel_documents` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `documents_id_mapping` | FK lookup | `travel_doc_identifier_upper`, `document_id` | - | - |

### `documents_id_mapping`

- **Output columns**: travel_doc_identifier_upper, document_id

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(tdim.travel_doc_identifier)))
    UPPER(TRIM(tdim.travel_doc_identifier)) as travel_doc_identifier_upper,
    d.id as document_id
FROM travel_document_identifier_mapping tdim

INNER JOIN document.documents d ON UPPER(TRIM(d.identifier)) = UPPER(TRIM(tdim.document_identifier))
WHERE tdim.document_identifier IS NOT NULL
ORDER BY UPPER(TRIM(tdim.travel_doc_identifier)), d.id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'travel_document_lists'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | identifier, mandatory_for | - | is_required | - | CASE WHEN UPPER(TRIM(legacy_data.identifier)) = 'PASSPORT' THEN true ELSE (legacy_data.mandatory_for > 0) END as is_required | CASE WHEN UPPER(TRIM(legacy_data.identifier)) = 'PASSPORT' THEN true ELSE (legacy_data.mandatory_for > 0) END |
| 5 | derived | - | is_compliant_check_required | - | false as is_compliant_check_required | false |
| 6 | - | - | description | - | NULL | NULL::text |
| 7 | derived | - | document_id | - | document_match.document_id as document_id | document_match.document_id |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | derived | - | status | - | 0 as status | 0 |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 18 | - | - | parent_id | - | NULL | NULL::uuid |
| 19 | - | - | tags | - | COALESCE( tag_match.tags, CASE WHEN document_match.document_id IS NOT NULL AND contract_check.is_contract THEN ARRAY['CON', 'seafarer_contract']::text[] ELSE NULL::text[] END ) ... | COALESCE( tag_match.tags, CASE WHEN document_match.document_id IS NOT NULL AND contract_check.is_contract THEN ARRAY['CON', 'seafarer_contract']::text[] ELSE NULL::text[] END ) |
| 20 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Documents ID Mapping
**Output columns**: `travel_doc_identifier_upper, document_id`

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(tdim.travel_doc_identifier)))
    UPPER(TRIM(tdim.travel_doc_identifier)) as travel_doc_identifier_upper,
    d.id as document_id
FROM travel_document_identifier_mapping tdim

INNER JOIN document.documents d ON UPPER(TRIM(d.identifier)) = UPPER(TRIM(tdim.document_identifier))
WHERE tdim.document_identifier IS NOT NULL
ORDER BY UPPER(TRIM(tdim.travel_doc_identifier)), d.id;
```

Full migration context: `04-migration-scripts/master/travel_documents_migration.sql`

## Validation

- Run `05-validation/master/travel_documents_validation.sql` if available
- Run `06-rollback/master/travel_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
