# Table Mapping: appraisal_debrief → seafarer_debrief_level_members

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: appraisal_debrief
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_debrief_level_members
- **Source Script**: `04-migration-scripts/crewing/seafarer_debrief_level_members_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.appraisal_debrief`
- **New Path**: `smac_crewing_migration.shore.seafarer_debrief_level_members`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debriefs (`seafarer_debrief_levels` → `seafarer_debrief_level_members`)

## Migration Notes

- Unpivot migration: one SMAC row per debriefer element in `feedback` JSONB array (joined to migrated `seafarer_debrief_levels`)
- Generates new UUID per row via `gen_random_uuid()` (composite source key: debrief level + debriefer)
- `debriefer_id` from JSONB → `user_id` and `reviewed_by` (UUID cast with validation)
- `role_name` → `assigned_to_user_type` (default `'Shore'`); `is_primary_reviewer` hardcoded `true`
- `feedback.status` → `review_status` (COMPLETED→Completed, PENDING→Pending); `responded_at` parsed as `DD/MM/YYYY`
- Requires `seafarer_debrief_levels` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_debrief_level_members` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `vessel_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per debriefer member row |
| 2 | `seafarer_debrief_levels.id` (derived) | uuid | `debrief_level_id` | uuid | From migrated `shore.seafarer_debrief_levels` | FK to parent debrief level |
| 3 | `feedback` → `debriefer_id` | jsonb | `user_id` | uuid | Cast `debriefer_id` to UUID when valid; nil UUID default | Extracted from unnested debriefer element |
| 4 | `feedback` → `role_name` | jsonb | `assigned_to_user_type` | text | `TRIM(role_name)`; default `'Shore'` | From debriefer JSONB element |
| 5 | — | — | `assigned_to_position_id` | uuid | `NULL` | No SAC equivalent |
| 6 | — | — | `is_primary_reviewer` | boolean | Hardcoded `true` | Per migration requirements |
| 7 | `feedback` → `status` | jsonb | `review_status` | text | COMPLETED→`Completed`, PENDING→`Pending`; else INITCAP | From feedback array element |
| 8 | `feedback` → `remarks` | jsonb | `remarks` | text | `TRIM(remarks)` from debriefer element | Nullable |
| 9 | `feedback` → `responded_at` | jsonb | `reviewed_at` | timestamp | `TO_TIMESTAMP(responded_at, 'DD/MM/YYYY')` when format matches | Parsed from feedback element |
| 10 | `feedback` → `debriefer_id` | jsonb | `reviewed_by` | uuid | Same UUID cast as `user_id`; NULL if invalid | Reviewer identity |
| 11 | `feedback` → `is_mail_send` | jsonb | `email_send` | boolean | Parse true/1/yes; default `true` | From debriefer element |
| 12 | `debrief_status` | text | `status` | text | Map Active/Inactive/Deleted; INITCAP fallback; default `Active` | From parent `appraisal_debrief` row |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | From parent debrief row |
| 15 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | From parent debrief row |
| 16 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 17 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | From parent debrief row |
| 18 | `created_by_id`, `deleted_by`, `updated_by_id`, `id` | mixed | `audit_info` | jsonb | Standard SMAC structure + `legacy_debrief_id`, `legacy_feedback_index`, `debriefer_element` | Custom audit metadata |

**SMAC columns not migrated:** `assigned_to_position_id`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** Most `appraisal_debrief` columns — only `feedback` array elements and audit timestamps used for member unpivot.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_debrief_levels`
- `seafarers`
- `vessel_types`
- `vessels`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_debrief_level_members_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debrief_level_members_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debrief_level_members_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
