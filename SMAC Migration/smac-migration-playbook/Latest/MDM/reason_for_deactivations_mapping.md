# Table Mapping: reason_for_deactivations → reason_for_deactivations

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: reason_for_deactivations
- **Source Script**: `04-migration-scripts/master/reason_for_deactivations_migration.sql`

- **New Path**: `smac_master_migration.crewing.reason_for_deactivations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Reason for Deactivations (`seafarer_profile_remarks` → `reason_for_deactivations`)

## Migration Notes

- Source: distinct `name` from `synergy_seafarer.public.seafarer_profile_remarks` WHERE `type = 'INACTIVE_PROFILE'`
- `resolve_target_id()` with source_id = truncated name; `p_target_id = NULL`
- `check_existing_mapping`/`resolve_target_id` use source_table `seafarer_profile_remarks`
- Staging aggregates description, MIN(created_at), MAX(updated_at) per distinct name
- TRUNCATE target
- Filter: non-empty `name`
- `status` hardcoded Active (0)
- `audit_info` notes preserve legacy name/description
## Special Considerations

- Script performs `TRUNCATE TABLE crewing.reason_for_deactivations` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `name` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = `LEFT(name, 100)`; `p_target_id = NULL` |  |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` |  |
| 3 | `name` | text | `name` | text | `LEFT(COALESCE(name, 'UNKNOWN'), 255)` |  |
| 4 | `description` | text | `description` | text | `LEFT(COALESCE(description, ''), 1000)` | MAX per distinct name |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 10 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(MIN(created_at), NOW())` per name |  |
| 11 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(MAX(updated_at), created_at, NOW())` |  |
| 12 | `name, description` | text | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; notes include legacy name/description |  |

**SAC columns not migrated:** `type` (used as filter only), other remark columns.

**SMAC columns not migrated:** `deleted_at`, `level`, `tags`.",
)

# --- reimbursement_categories ---
set_update(
    "reimbursement_categories",
    [
        "- Source: `synergy_crewwage.public.reimbursement_categories` CROSS JOIN `crewing.reimbursement_types`",
        "- Each legacy category replicated per reimbursement type (categories × types)",
        "- `resolve_target_id()` with composite source_id = `legacy.id || '-' || rt.id`; `p_target_id = NULL`",
        "- Requires `reimbursement_types` populated first",
        "- DELETE mappings + TRUNCATE target",
        "- Filter: `id IS NOT NULL AND TRIM(name) <> ''`",
        "- `status` Case 1 from `deleted_at`",
    ],
    [
        row(1, "id, reimbursement_type.id", "bigint, uuid", "id", "uuid", "`migration.resolve_target_id()` — source_id = `id::text || '-' || rt.id`; `p_target_id = NULL`", "Composite key
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/reason_for_deactivations_migration.sql`

## Validation

- Run `05-validation/master/reason_for_deactivations_validation.sql` if available
- Run `06-rollback/master/reason_for_deactivations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
