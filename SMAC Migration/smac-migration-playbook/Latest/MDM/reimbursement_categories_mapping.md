# Table Mapping: reimbursement_categories → reimbursement_categories

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: reimbursement_categories
- **Source Script**: `04-migration-scripts/master/reimbursement_categories_migration.sql`

- **New Path**: `smac_master_migration.crewing.reimbursement_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- Source: `synergy_crewwage.public.reimbursement_categories` CROSS JOIN `crewing.reimbursement_types`
- Each legacy category replicated per reimbursement type (categories × types)
- `resolve_target_id()` with composite source_id = `legacy.id || '-' || rt.id`; `p_target_id = NULL`
- Requires `reimbursement_types` populated first
- DELETE mappings + TRUNCATE target
- Filter: `id IS NOT NULL AND TRIM(name) <> ''`
- `status` Case 1 from `deleted_at`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.reimbursement_categories` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, reimbursement_type.id` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text || '-' || rt.id`; `p_target_id = NULL` | Composite key |
| 2 | `name, rt.name` | text, text | `code` | text | `generate_meaningful_code(legacy.name, rt.name)` |  |
| 3 | `name` | text | `name` | text | `LEFT(TRIM(name), 255)` |  |
| 4 | `—` | — | `description` | text | `NULL` |  |
| 5 | `—` | — | `reimbursement_type_id` | uuid | `rt.id` from CROSS JOIN | FK from target types table |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 12 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 13 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 15 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 16 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 17 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 18 | `—` | — | `tags` | text[] | `NULL` |  |

**SAC columns not migrated:** None from dblink SELECT.

**Note:** Row count = legacy categories × reimbursement_types count.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/reimbursement_categories_migration.sql`

## Validation

- Run `05-validation/master/reimbursement_categories_validation.sql` if available
- Run `06-rollback/master/reimbursement_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
