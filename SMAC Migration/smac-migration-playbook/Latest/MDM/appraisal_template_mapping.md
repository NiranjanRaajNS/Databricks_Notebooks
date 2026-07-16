# Table Mapping: appraisal_templates → appraisal_template

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: appraisal_templates
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: appraisal_template
- **Source Script**: `04-migration-scripts/master/appraisal_template_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates`
- **New Path**: `smac_master_migration.crewing.appraisal_template`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `appraisal_template`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `code` generated from `template_name` via `generate_meaningful_code()`
- Filter: `id IS NOT NULL`; `DISTINCT ON (id)`
- Manual mapping storage to `migration.table_mappings` after insert

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE crewing.appraisal_template` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `template_name` | text | `code` | text | `generate_meaningful_code(TRIM(template_name), NULL)` | Generated from template_name |
| 3 | `template_name` | text | `name` | text | `COALESCE(NULLIF(TRIM(template_name), ''), 'Appraisal Template ' || RIGHT(id::text, 8))` | NOT NULL in SMAC |
| 4 | `template` | jsonb | `template` | jsonb | Direct copy; fallback `'Default Template'` jsonb when NULL | NOT NULL in SMAC |
| 5 | `template_type` | text | `template_type` | text | `NULLIF(TRIM(template_type), '')` | Direct copy |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status column in SAC |
| 11 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No timestamps in SAC source SELECT |
| 12 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | No timestamps in SAC source SELECT |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in SAC |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` | No level column in SAC |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/appraisal_template_migration.sql`

## Validation

- Run `05-validation/master/appraisal_template_validation.sql` if available
- Run `06-rollback/master/appraisal_template_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
