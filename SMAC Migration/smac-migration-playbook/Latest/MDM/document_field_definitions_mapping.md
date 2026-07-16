# Table Mapping: document_field_definition → document_field_definitions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_field_definition
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_field_definitions
- **Source Script**: `04-migration-scripts/master/document_field_definitions_migration.sql`

- **Legacy Path**: `synergy_master.document.document_field_definition`
- **New Path**: `smac_master_migration.document.document_field_definitions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Field Definition (`document_field_definition` → `document_field_definitions`)

## Migration Notes

- Source: `synergy_master.document.document_field_definition` (singular)
- SAC `id` preserved; `document_id`/`document_part_id` via `migration.table_mappings` for `documents`
- Filter: skip rows where `document_id` mapping not found
- Country field: `meta_data.DataSourceInfo` standardized to SMAC Countries master
- `status` from `is_active`; `level` from SAC `order` column
- Hardcoded INSERT: vaccine dropdown field for COVID-19 document


## Special Considerations

- Requires documents table to be migrated first (for document_id and document_part_id mapping)
- Script performs `TRUNCATE TABLE document.document_field_definitions` before insert (full table reload).
- Orchestration dependencies: `documents`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `document_id` | uuid | `document_id` | uuid | Map via `migration.table_mappings` where `target_table = 'documents'` | Required FK; rows without mapping skipped |
| 3 | `document_part_id` | uuid | `document_part_id` | uuid | Map via documents mapping; fallback empty GUID | Optional part reference |
| 4 | `name`, `id` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), id::text)` | |
| 5 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 6 | `label` | text | `label` | text | `TRIM(label)` | |
| 7 | `type` | text | `type` | text | `TRIM(type)` | |
| 8 | `is_required` | boolean | `is_required` | boolean | `COALESCE(is_required, false)` | |
| 9 | `is_readonly` | boolean | `is_readonly` | boolean | `COALESCE(is_readonly, false)` | |
| 10 | `meta_data` | jsonb | `meta_data` | jsonb | Country field: rewrite DataSourceInfo to SMAC Countries; else direct copy | Special country DefaultValue resolution |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 12 | — | — | `version` | integer | Hardcoded `1` | |
| 13 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 14 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 15 | `is_active` | boolean | `status` | integer | `is_active = true` â†’ Active (0); else Inactive (2) | |
| 16 | `order` | integer | `level` | numeric | `COALESCE(order, 0)` | SAC `order` â†’ SMAC `level` |
| 17 | `updated_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 18 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | Direct copy | |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |
| 20 | `name`, `id` | text, uuid | `tags` | text[] | Distinct lowercase tags from code + normalized name | Derived |

**Additional seed record (not from SAC):** Hardcoded vaccine dropdown field (`id = 2cf8c29e-...`) for COVID-19 Vaccination Certificate.


## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.documents`
- `documents`
- `public.countries`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_field_definitions_migration.sql`

## Validation

- Run `05-validation/master/document_field_definitions_validation.sql` if available
- Run `06-rollback/master/document_field_definitions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
