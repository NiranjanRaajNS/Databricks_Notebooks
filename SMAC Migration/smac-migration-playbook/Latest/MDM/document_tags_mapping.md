# Table Mapping: document_tags → document_tags

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_tags
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_tags
- **Source Script**: `04-migration-scripts/master/document_tags_migration.sql`

- **Legacy Path**: `synergy_master.document.document_tags`
- **New Path**: `smac_master_migration.document.document_tags`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Tags (`document_tags` → `document_tags`)

## Migration Notes

- Source: `synergy_master.document.document_tags`
- SAC `id` preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- Second INSERT block: seed tags (dce expiry, passport, training, etc.) not from SAC


## Special Considerations

- Script performs `TRUNCATE TABLE document.document_tags` before insert (full table reload).

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
| 8 | `status` | text | `status` | integer | Map status text/numeric to integer | |
| 9 | — | — | `level` | numeric | Hardcoded `0` | |
| 10 | `audit_info` | jsonb | `created_at` | timestamp without time zone | Extract `CreatedAt`; fallback `NOW()` | |
| 11 | `audit_info` | jsonb | `updated_at` | timestamp without time zone | Extract `UpdatedAt`; fallback `NOW()` | |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |
| 13 | `name`, `code` | text | `tags` | text[] | Distinct lowercase tags from normalized name + code | Derived |

**Additional seed records (not from SAC):** ~15 hardcoded document tags inserted via second INSERT block.


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/document_tags_migration.sql`

## Validation

- Run `05-validation/master/document_tags_validation.sql` if available
- Run `06-rollback/master/document_tags_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
