# Table Mapping: document_sections → document_sections

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_sections
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_sections
- **Source Script**: `04-migration-scripts/master/document_sections_migration.sql`

- **Legacy Path**: `synergy_master.document.document_sections`
- **New Path**: `smac_master_migration.document.document_sections`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Sections (`document_sections` → `document_sections`)

## Migration Notes

- Source: `synergy_master.document.document_sections`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- Timestamps extracted from SAC `audit_info` JSONB
- Filter: non-empty `name`


## Special Considerations

- Script performs `TRUNCATE TABLE document.document_sections` before insert (full table reload).
- Orchestration dependencies: `document_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `code`, `name` | text | `code` | text | `COALESCE(NULLIF(TRIM(code), ''), LEFT(TRIM(name), 10))` | |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 5 | — | — | `version` | integer | Hardcoded `1` | |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 8 | `status` | text | `status` | integer | Map status text/numeric to Active/Draft/Inactive/Deleted | |
| 9 | — | — | `level` | numeric | Hardcoded `0` | |
| 10 | `audit_info` | jsonb | `created_at` | timestamp without time zone | Extract `CreatedAt`; fallback `NOW()` | |
| 11 | `audit_info` | jsonb | `updated_at` | timestamp without time zone | Extract `UpdatedAt`; fallback `NOW()` | |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- `document_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_sections_migration.sql`

## Validation

- Run `05-validation/master/document_sections_validation.sql` if available
- Run `06-rollback/master/document_sections_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
