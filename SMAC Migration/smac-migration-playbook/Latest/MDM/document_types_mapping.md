# Table Mapping: document_types → document_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_types
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_types
- **Source Script**: `04-migration-scripts/master/document_types_migration.sql`

- **Legacy Path**: `synergy_master.document.document_types`
- **New Path**: `smac_master_migration.document.document_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Types (`document_types` → `document_types`)

## Migration Notes

- Source: `synergy_master.document.document_types`
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `level` from `ROW_NUMBER() OVER (ORDER BY name)`
- `created_at`/`updated_at` extracted from SAC `audit_info` JSONB (`CreatedAt`/`UpdatedAt`)
- `status` mapped from text status (no `deleted_at` in source)


## Special Considerations

- Script performs `TRUNCATE TABLE document.document_types` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `code`, `name` | text | `code` | text | `COALESCE(NULLIF(TRIM(code), ''), LEFT(TRIM(name), 10))` | Fallback to name prefix |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 5 | — | — | `version` | integer | Hardcoded `1` | |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 8 | `status` | text | `status` | integer | Map ACTIVE/DRAFT/INACTIVE/DELETED text or numeric string to integer | No `deleted_at` |
| 9 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name)) - 1` | Alphabetical hierarchy |
| 10 | `audit_info` | jsonb | `created_at` | timestamp without time zone | Extract `CreatedAt` from audit_info; fallback `NOW()` | |
| 11 | `audit_info` | jsonb | `updated_at` | timestamp without time zone | Extract `UpdatedAt` from audit_info; fallback `NOW()` | |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | SAC audit_info not mapped directly |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_types_migration.sql`

## Validation

- Run `05-validation/master/document_types_validation.sql` if available
- Run `06-rollback/master/document_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
