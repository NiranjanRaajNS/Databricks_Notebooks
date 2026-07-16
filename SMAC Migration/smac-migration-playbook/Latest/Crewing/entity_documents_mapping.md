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

- SAC `seafarer_signoff_documents` grouped by `mapper_uuid` — one SMAC row per `mapper_uuid` (`DISTINCT ON`)
- SAC `mapper_uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = mapper_uuid`
- `reference_entity` hardcoded `'SeafarerSignOff'`; `sign_off_detail_id` not mapped to `reference_id`
- `workflow_status_id` = APPROVED from `workflow_status` master (dblink)
- `created_at`/`updated_at` aggregated MIN/MAX per `mapper_uuid` partition
- Child files migrated separately in `entity_document_files`

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
| 1 | `mapper_uuid` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `mapper_uuid::text`; `p_target_id = mapper_uuid` | One row per `mapper_uuid`; preserves UUID |
| 2 | — | — | `reference_entity` | text | Hardcoded `'SeafarerSignOff'` | SMAC polymorphic reference type |
| 3 | `sign_off_detail_id` | bigint | `reference_id` | uuid | `NULL` | Not mapped (would need signoff_details mapping) |
| 4 | — | — | `document_id` | uuid | `NULL` | No equivalent in SAC |
| 5 | — | — | `document_parts_id` | uuid | `NULL` | No equivalent in SAC |
| 6 | — | — | `reference_number` | text | `NULL` | No equivalent in SAC |
| 7 | — | — | `issue_date` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 8 | — | — | `expiry_date` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 9 | — | — | `issuing_authority` | text | `NULL` | No equivalent in SAC |
| 10 | — | — | `place_of_issue` | text | `NULL` | No equivalent in SAC |
| 11 | — | — | `remarks` | text | `NULL` | No equivalent in SAC |
| 12 | — | — | `has_document` | boolean | Hardcoded `true` | SMAC default |
| 13 | — | — | `no_document_reason` | text | `NULL` | No equivalent in SAC |
| 14 | — | — | `version` | integer | Hardcoded `1` | SMAC default |
| 15 | — | — | `bypass_status` | text | `NULL` | No equivalent in SAC |
| 16 | — | — | `bypass_reason_id` | uuid | `NULL` | No equivalent in SAC |
| 17 | — | — | `bypass_by_id` | uuid | `NULL` | No equivalent in SAC |
| 18 | — | — | `bypass_reason` | text | `NULL` | No equivalent in SAC |
| 19 | — | — | `has_attachments` | boolean | Hardcoded `true` | Files in `entity_document_files` |
| 20 | — | — | `form_response` | text | `NULL` | No equivalent in SAC |
| 21 | — | — | `supporting_documents` | text | `NULL` | No equivalent in SAC |
| 22 | — | — | `metadata` | text | `NULL` | No equivalent in SAC |
| 23 | — | — | `workflow_status_id` | uuid | APPROVED from `workflow_status_id_mapping`; default nil UUID | Lookup: dblink `workflow_status` |
| 24 | — | — | `progress_status` | text | `NULL` | No equivalent in SAC |
| 25 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 26 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC |
| 27 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC |
| 28 | — | — | `approved_by_id` | uuid | `NULL` | No equivalent in SAC |
| 29 | — | — | `approved_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 30 | — | — | `approval_notes` | text | `NULL` | No equivalent in SAC |
| 31 | — | — | `status` | integer | Hardcoded `0` (Active per `constants.sql`) | NOT NULL |
| 32 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 33 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `MIN(created_at)` per `mapper_uuid` partition | Aggregated across file rows |
| 34 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `MAX(updated_at)` per `mapper_uuid` partition | Aggregated across file rows |
| 35 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 36 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC `deleted_at` on file rows not aggregated |
| 37 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all fields NULL | Aggregated row has no single audit source |
| 38 | `document_name` | text | `document_name` | text | `TRIM(document_name)` | From grouped SAC rows |
| 39 | — | — | `sefarer_document_id` | uuid | `NULL` | No equivalent in SAC |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `id` (bigint row id), `file_name`, `url`, `content_type`, `content_size` — file-level columns migrated in `entity_document_files`; `sign_off_detail_id` not mapped to `reference_id`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `workflow_status`

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
