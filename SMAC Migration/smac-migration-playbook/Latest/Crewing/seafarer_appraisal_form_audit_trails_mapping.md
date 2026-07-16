# Table Mapping: seafarer_appraisal_forms → seafarer_appraisal_form_audit_trails

## Overview
- **Legacy Database**: smac_crewing_migration
- **Legacy Schema**: public
- **Legacy Table**: seafarer_appraisal_forms
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_appraisal_form_audit_trails
- **Source Script**: `04-migration-scripts/crewing/seafarer_appraisal_form_audit_trails_migration.sql`

- **Legacy Path**: `smac_crewing_migration.public.seafarer_appraisal_forms`
- **New Path**: `smac_crewing_migration.public.seafarer_appraisal_form_audit_trails`

## Business Key

- **Business Key**: `appraisal_form_id` — one audit trail row per source `seafarer_appraisal_forms` record
- **Source (orchestration)**: Appraisals (`seafarer_appraisal_forms` → `seafarer_appraisal_form_audit_trails`)

## Migration Notes

- **Same-database enrichment migration** — source is already-migrated `public.seafarer_appraisal_forms` (not a SAC legacy table)
- Creates one audit trail row per appraisal form with `gen_random_uuid()` for `id` (not `migration.resolve_target_id()`)
- `action_type`: `'Submitted'` when `UPPER(TRIM(form_status)) = 'COMPLETED'`, else `'Created'`
- `action_data` JSONB snapshot built from form metadata: `formId`, `stageType`, `assignedTo`, `sequenceOrder`, `formDefinitionId`
- `performed_by_id` from `audit_info.created_by` when valid UUID format; else `:'SYSTEM_USER_ID'::uuid` from `constants.sql`
- `performed_at` set to `NOW()` — no historical action timestamp available in source forms
- Repeated-migration detection keyed on `seafarer_appraisal_forms` → `seafarer_appraisal_form_audit_trails` via `migration.check_existing_mapping()`
- No TRUNCATE — inserts audit trails for all rows in `seafarer_appraisal_forms`
- Requires `seafarer_appraisal_forms` populated first (via `seafarer_appraisal_forms_migration.sql` and/or `seafarer_appraisal_form_update_migration.sql`)

## Special Considerations

- 1:1 relationship — each `seafarer_appraisal_forms` row produces exactly one audit trail row
- Source and target reside in the same database (`smac_crewing_migration`)
- Orchestration dependencies: `seafarer_appraisal_forms`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per audit trail row; not idempotent |
| 2 | `id` | uuid | `appraisal_form_id` | uuid | Direct copy `saf.id` | FK to parent appraisal form |
| 3 | `form_status` | text | `action_type` | text | `UPPER(TRIM(form_status)) = 'COMPLETED'` → `'Submitted'`; else `'Created'` | Case-insensitive status check |
| 4 | `id`, `stage_type`, `assigned_to_user_id`, `sequence_order`, `form_definition_id` | uuid, text, uuid, integer, uuid | `action_data` | jsonb | `jsonb_build_object('formId', 'stageType', 'assignedTo', 'sequenceOrder', 'formDefinitionId')` | Snapshot of form state at migration time |
| 5 | `audit_info` → `created_by` | text | `performed_by_id` | uuid | Valid UUID regex on `audit_info->>'created_by'`; else `:'SYSTEM_USER_ID'::uuid` | From `constants.sql` when unmapped |
| 6 | — | — | `performed_at` | timestamp without time zone | `NOW()` | No historical action timestamp in source |

**SMAC source columns not migrated:** All other `seafarer_appraisal_forms` columns (`appraisal_id`, `submission_data`, `form_template`, `tenant_id`, `created_at`, `updated_at`, `deleted_at`, etc.) — not copied to audit trail; only fields listed above are used.

**SAC columns not migrated:** N/A — source is SMAC `seafarer_appraisal_forms`, not a SAC legacy table.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_appraisal_forms`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_appraisal_form_audit_trails_migration.sql`

Key transformation patterns:
- **Action type derivation**: `form_status` string mapped to audit `action_type` (`COMPLETED` → `Submitted`, all others → `Created`)
- **Action data snapshot**: Selected form fields serialized to JSONB for audit context
- **Performer resolution**: `audit_info.created_by` UUID validated via regex; falls back to system user constant

## Validation

- Run `05-validation/crewing/seafarer_appraisal_form_audit_trails_validation.sql` if available
- Run `06-rollback/crewing/seafarer_appraisal_form_audit_trails_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
