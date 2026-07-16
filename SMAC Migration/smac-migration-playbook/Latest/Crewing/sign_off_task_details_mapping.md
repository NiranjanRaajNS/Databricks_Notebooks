# Table Mapping: sign_off_details → sign_off_task_details

## Overview
- **Legacy Database**: smac_crewing_migration
- **Legacy Schema**: public
- **Legacy Table**: sign_off_details (joined with `seafarer_appraisals` via `seafarer_vessel_assignments`)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: sign_off_task_details
- **Source Script**: `04-migration-scripts/master/sign_off_task_details_migration.sql`

- **Legacy Path**: `smac_crewing_migration.public.sign_off_details` + `smac_crewing_migration.public.seafarer_appraisals`
- **New Path**: `smac_crewing_migration.public.sign_off_task_details`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Sign Off Task Details (`signoff_details` → `sign_off_task_details`)

## Migration Notes

- **Same-database enrichment migration** — source is already-migrated `public.sign_off_details` joined with `public.seafarer_appraisals` (not a SAC legacy table)
- Join path: `sign_off_details.assignment_id` → `seafarer_vessel_assignments.id`; match appraisals on `seafarer_id` + `vessel_id`
- Filter: `sign_off_status = 0` (Initiated) AND `appraisal_type_id` IN valid appraisal types (`'SIGN OFF'`, `'MID TERM'` from `crewing.appraisal_types` via dblink)
- `DISTINCT ON (sign_off_details.id)` — one task row per sign-off detail; prefers latest appraisal by `vessel_revision_id DESC`, then `created_at DESC`
- `id` generated via `gen_random_uuid()` per row (not `migration.resolve_target_id()`; mapping storage commented out in script)
- `task_code` hardcoded `'APPRAISAL'` (`seafarer_appraisals` has no `code` column)
- `completion_status` derived from joined `seafarer_appraisals.appraisal_status` text → integer enum
- `status` derived from `sign_off_details.deleted_at` (Case 1 — `deleted_at` takes precedence)
- `audit_info` via `migration.build_audit_info()` with `legacy_id` appended as sign-off detail UUID
- Script performs `TRUNCATE TABLE public.sign_off_task_details` before insert (full table reload)
- Requires `sign_off_details`, `seafarer_vessel_assignments`, and `seafarer_appraisals` populated first

## Special Considerations

- Orchestration config lists `contract_assignments` and `appraisal_types` as dependencies; script joins via `assignment_id` → `seafarer_vessel_assignments` and queries `appraisal_types` from `smac_master_migration` via dblink
- Appraisal join columns (`appraisal_id`, `appraisal_type_id`, `vessel_revision_id`) used for filtering/selection only — not written to target
- Orchestration dependencies: `signoff_details`, `seafarer_appraisals`, `seafarer_vessel_assignments`, `appraisal_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script.

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `valid_appraisal_type_ids` | Appraisal type filter | `id` | - | `smac_master_migration` |

### `valid_appraisal_type_ids`

- **Output columns**: id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE valid_appraisal_type_ids AS
SELECT id
FROM dblink('smac_master_migration',
    'SELECT id FROM crewing.appraisal_types WHERE UPPER(TRIM(name)) IN (''SIGN OFF'', ''MID TERM'')'
) AS at(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | New UUID per row; not idempotent |
| 2 | `sign_off_details.id` | uuid | `sign_off_id` | uuid | Direct copy from `sign_off_details.id` | FK to parent sign-off detail |
| 3 | — | — | `task_code` | text | Hardcoded `'APPRAISAL'` | Constant task type; `seafarer_appraisals` has no code column |
| 4 | `seafarer_appraisals.appraisal_status` | text | `completion_status` | integer | CASE map: PENDING/INITIATED/DRAFT/ACTIVE→0, INPROGRESS/IN_PROGRESS/SUBMITTED/UNDERREVIEW→1, COMPLETED/COMPLET/CLOSED/FINISHED→2, SKIPPED/CANCELLED/CANCELED/ABANDONED→3; else 0 | From joined appraisal row selected by `DISTINCT ON` |
| 5 | `sign_off_details.remarks` | text | `remarks` | text | Direct copy | Sourced as `notes` in staging temp table |
| 6 | — | — | `skip_reason_id` | uuid | `NULL` | No equivalent in source |
| 7 | — | — | `skip_remarks` | text | `NULL` | No equivalent in source |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in source |
| 9 | `sign_off_details.deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 10 | `sign_off_details.created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From sign_off_details |
| 11 | `sign_off_details.updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | From sign_off_details |
| 12 | `sign_off_details.deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 13 | `sign_off_details.audit_info` → `created_by`, `updated_by`; `remarks` | text | `audit_info` | jsonb | `migration.build_audit_info()` merged with `jsonb_build_object('legacy_id', sign_off_detail_id::text)` | `remarks` passed as `notes`; `legacy_id` = sign-off detail UUID |

**SMAC source columns not migrated:** `sign_off_details.sign_off_status`, `assignment_id`, `description`, and other sign-off detail fields — used for join/filter only or not referenced. `seafarer_appraisals.id`, `appraisal_type_id`, `vessel_revision_id` — used for join/filter/selection only.

**SAC columns not migrated:** N/A — source is SMAC `sign_off_details` + `seafarer_appraisals`, not SAC legacy tables.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `sign_off_details`
- `seafarer_vessel_assignments`
- `seafarer_appraisals`
- `appraisal_types` (queried from `smac_master_migration` via dblink)

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables — see **ID Mappings** section above.

Key transformation patterns:
- **Sign-off to appraisal join**: `sign_off_details.assignment_id` → `seafarer_vessel_assignments` → match `seafarer_appraisals` on `seafarer_id` + `vessel_id`
- **Appraisal type filter**: Only `'SIGN OFF'` and `'MID TERM'` appraisal types (case-insensitive name match)
- **Deduplication**: `DISTINCT ON (sign_off_details.id)` keeps one appraisal per sign-off detail (latest revision/created date)
- **Completion status**: Text `appraisal_status` mapped to integer enum (Pending=0, InProgress=1, Completed=2, Skipped=3)

Full migration context: `04-migration-scripts/master/sign_off_task_details_migration.sql`

## Validation

- Run `05-validation/master/sign_off_task_details_validation.sql` if available
- Run `06-rollback/master/sign_off_task_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
