# Table Mapping: disciplinary_reasons → disciplinary_reasons

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: disciplinary_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: disciplinary_reasons
- **Source Script**: `04-migration-scripts/master/disciplinary_reasons_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.disciplinary_reasons`
- **New Path**: `smac_master_migration.crewing.disciplinary_reasons`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Disciplinary Reasons (`disciplinary_reasons` → `disciplinary_reasons`)

## Migration Notes

- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `code` generated from `name` — first 15 chars, uppercase, underscores (no UUID suffix)
- `status` hardcoded Active (0); no `deleted_at` in source
- Filter: `TRIM(COALESCE(name, '')) <> ''`


## Special Considerations

- Script performs `TRUNCATE TABLE crewing.disciplinary_reasons` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved; Pattern 4 |
| 2 | `name` | text | `code` | text | `UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_'))` | Generated from name |
| 3 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `COALESCE(NULLIF(TRIM(description), ''), '')` | Empty string when NULL |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 6 | — | — | `version` | integer | Hardcoded `1` | |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 9 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in SAC |
| 10 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 11 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 12 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — IDs and names in `notes` | No `legacy_id` (uuid preserved as `id`) |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/disciplinary_reasons_migration.sql`

## Validation

- Run `05-validation/master/disciplinary_reasons_validation.sql` if available
- Run `06-rollback/master/disciplinary_reasons_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
