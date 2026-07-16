# Table Mapping: seafarer_signoff_documents → entity_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: entity_documents
- **Source Script**: `04-migration-scripts/crewing/entity_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_documents`
- **New Path**: `smac_crewing_migration.public.entity_documents`

## Business Key

- **Business Key**: `mapper_uuid`
- **Source (orchestration)**: Entity Documents (`seafarer_signoff_documents` → `entity_documents`)

## Migration Notes

- Migrates seafarer_signoff_documents to entity_documents. Groups by mapper_uuid (one entity_document per mapper_uuid). Sets reference_entity to 'SeafarerSignOff'. Uses default workflow_status_id from workflow_status table.

## Special Considerations

- Script performs `TRUNCATE TABLE public.entity_documents` before insert (full table reload).
- Orchestration dependencies: `workflow_status`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | mapper_uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.mapper_uuid) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_signoff_documents'::VARCHAR(100), legacy_da... |
| 2 | derived | - | reference_entity | - | 'SeafarerSignOff'::text AS reference_entity | 'SeafarerSignOff'::text |
| 3 | - | - | reference_id | - | NULL | NULL::uuid |
| 4 | - | - | document_id | - | NULL | NULL::uuid |
| 5 | - | - | document_parts_id | - | NULL | NULL::uuid |
| 6 | - | - | reference_number | - | NULL | NULL::text |
| 7 | - | - | issue_date | - | NULL | NULL::timestamp |
| 8 | - | - | expiry_date | - | NULL | NULL::timestamp |
| 9 | - | - | issuing_authority | - | NULL | NULL::text |
| 10 | - | - | place_of_issue | - | NULL | NULL::text |
| 11 | - | - | remarks | - | NULL | NULL::text |
| 12 | derived | - | has_document | - | true AS has_document | true |
| 13 | - | - | no_document_reason | - | NULL | NULL::text |
| 14 | derived | - | version | - | 1 AS version | 1 |
| 15 | - | - | bypass_status | - | NULL | NULL::text |
| 16 | - | - | bypass_reason_id | - | NULL | NULL::uuid |
| 17 | - | - | bypass_by_id | - | NULL | NULL::uuid |
| 18 | - | - | bypass_reason | - | NULL | NULL::text |
| 19 | derived | - | has_attachments | - | true AS has_attachments | true |
| 20 | - | - | form_response | - | NULL | NULL::text |
| 21 | - | - | supporting_documents | - | NULL | NULL::text |
| 22 | - | - | metadata | - | NULL | NULL::text |
| 23 | derived | - | workflow_status_id | - | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) AS workflow_status_id | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 24 | - | - | progress_status | - | NULL | NULL::text |
| 25 | - | - | verified_at | - | NULL | NULL::timestamp |
| 26 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 27 | - | - | verification_notes | - | NULL | NULL::text |
| 28 | - | - | approved_by_id | - | NULL | NULL::uuid |
| 29 | - | - | approved_at | - | NULL | NULL::timestamp |
| 30 | - | - | approval_notes | - | NULL | NULL::text |
| 31 | derived | - | status | - | 0 AS status | 0 |
| 32 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 33 | created_at, mapper_uuid | - | created_at | - | MIN(legacy_data.created_at) OVER (PARTITION BY legacy_data.mapper_uuid) AS created_at | MIN(legacy_data.created_at) OVER (PARTITION BY legacy_data.mapper_uuid) |
| 34 | updated_at, mapper_uuid | - | updated_at | - | MAX(legacy_data.updated_at) OVER (PARTITION BY legacy_data.mapper_uuid) AS updated_at | MAX(legacy_data.updated_at) OVER (PARTITION BY legacy_data.mapper_uuid) |
| 35 | - | - | archived_at | - | NULL | NULL::timestamp |
| 36 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 37 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 38 | document_name | - | document_name | - | TRIM(legacy_data.document_name) AS document_name | TRIM(legacy_data.document_name) |
| 39 | - | - | sefarer_document_id | - | NULL | NULL::uuid |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/entity_documents_migration.sql`

## Validation

- Run `05-validation/crewing/entity_documents_validation.sql` if available
- Run `06-rollback/crewing/entity_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
