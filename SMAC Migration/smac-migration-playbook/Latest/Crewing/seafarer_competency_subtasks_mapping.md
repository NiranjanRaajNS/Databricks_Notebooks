# Table Mapping: seafarer_competency_subtasks → seafarer_competency_subtasks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_subtasks
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_subtasks
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_subtasks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_subtasks`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_subtasks`

## Business Key

- **Composite Key**: (`competency_id`, `subtask_id`, `seafarer_uuid`)
- **Source (orchestration)**: Seafarer Competency Subtasks (`seafarer_competency_subtasks` → `seafarer_competency_subtasks`)

## Migration Notes

- SAC `id` (uuid) preserved as target `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `task_id` copied directly to `seafarer_task_id` (UUID preserved from `seafarer_competency_tasks` migration)
- `seafarer_uuid` copied directly to `seafarer_id` (matches preserved `seafarers.id`)
- `comments`, `history`, `attachment_ids` (jsonb) cast to text
- `workflow_status_id` defaults to first `workflow_status` from `smac_master_migration`, else nil UUID
- Rows with NULL `task_id` or `seafarer_uuid` are excluded
- Requires `seafarer_competency_tasks` and `seafarers` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_subtasks` before insert (full table reload).
- Orchestration dependencies: `seafarer_competency_tasks`, `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves legacy UUID |
| 2 | `task_id` | uuid | `seafarer_task_id` | uuid | Direct copy (`task_id` → `seafarer_task_id`) | FK to `seafarer_competency_tasks.id` (preserved UUID) |
| 3 | `subtask_id` | uuid | `subtask_id` | uuid | Direct copy | Master subtask reference |
| 4 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Direct copy (`seafarer_uuid` → `seafarer_id`) | FK to `seafarers.id` (preserved UUID) |
| 5 | `comments` | jsonb | `comments` | text | jsonb → text (`::text`) | Type change jsonb → text |
| 6 | `history` | jsonb | `history` | text | jsonb → text (`::text`) | Type change jsonb → text |
| 7 | `attachment_ids` | jsonb | `attachment_ids` | text | jsonb → text (`::text`) | Type change jsonb → text |
| 8 | — | — | `workflow_status_id` | uuid | `COALESCE(default_workflow_status.id, nil UUID)` | Lookup: first `workflow_status` from `smac_master_migration` |
| 9 | — | — | `is_verified` | boolean | Hardcoded `FALSE` | Not in SAC |
| 10 | — | — | `verified_at` | timestamp | `NULL` | No SAC equivalent |
| 11 | — | — | `verified_by_id` | uuid | `NULL` | No SAC equivalent |
| 12 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 13 | `status` | text | `status` | text | `TRIM(COALESCE(status, ''))` | NOT NULL; empty string default |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `created_at` | timestamp(6) | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 16 | `updated_at` | timestamp(6) | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 17 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 18 | `deleted_at` | timestamp(6) | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 19 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `approved_on`, `approved_by`, `rejected_by`, `created_by_name`, `updated_by_name` | varchar, uuid, timestamp | `audit_info` | jsonb | `migration.build_audit_info()` — `approved_on`/`approved_by`/`rejected_by` populated; legacy task/seafarer IDs in `notes` | Standardized SMAC audit structure |
| 20 | — | — | `name` | text | `NULL` | New optional SMAC field |

**SMAC columns not migrated:** `name`, verification fields (`is_verified`, `verified_at`, `verified_by_id`, `verification_notes`) — set to defaults/NULL.

**SAC columns not migrated:** `competency_id`, `rejected_on` — not referenced in target INSERT (`competency_id` superseded by `task_id`; `rejected_on` not mapped to separate column).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_competency_tasks`
- `seafarers`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_competency_subtasks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_subtasks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_subtasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
