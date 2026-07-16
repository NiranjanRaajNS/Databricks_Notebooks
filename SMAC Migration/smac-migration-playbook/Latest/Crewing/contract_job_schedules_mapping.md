# Table Mapping: scheduled_job → contract_job_schedules

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: scheduled_job
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: contract_job_schedules
- **Source Script**: `04-migration-scripts/crewing/contract_job_schedules_migration.sql`

- **Legacy Path**: `synergy_manning.public.scheduled_job`
- **New Path**: `smac_crewing_migration.shore.contract_job_schedules`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Contract Job Schedules (`scheduled_job` → `contract_job_schedules`)

## Migration Notes

- Source table `scheduled_job` has column names with trailing spaces (e.g. `"status "`, `"job_identifier "`)
- Filter: only rows where `"status "` = `'Scheduled'` are migrated
- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `scheduled_at` and `created_at` cast from `timestamptz` to `timestamp`
- `updated_at` set to `NOW()` (not sourced from legacy `updated_at`)
- Default `retry_count = 0`, `max_retries = 3`; empty `audit_info` JSONB

## Special Considerations

- Script performs `TRUNCATE TABLE shore.contract_job_schedules` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID; target schema `shore` |
| 2 | `job_identifier` | character varying | `job_code` | text | `TRIM(job_identifier)` | SAC column quoted as `"job_identifier "`; NOT NULL |
| 3 | `meta_data` | jsonb | `job_payload` | jsonb | `COALESCE(meta_data, '{}'::jsonb)` | SAC column quoted as `"meta_data "`; NOT NULL |
| 4 | `scheduled_at` | timestamp with time zone | `scheduled_for` | timestamp without time zone | Cast `timestamptz` → `timestamp` | SAC column quoted as `"scheduled_at "`; NOT NULL |
| 5 | `type` | character varying | `job_type` | text | `TRIM(type)` | SAC column quoted as `"type "`; NOT NULL |
| 6 | `status` | character varying | `job_status` | text | `COALESCE(TRIM(status), 'pending')` | SAC column quoted as `"status "`; filter requires `'Scheduled'` |
| 7 | — | — | `last_run_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 8 | — | — | `next_run_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 9 | — | — | `retry_count` | integer | Hardcoded `0` | SMAC default; not in SAC source |
| 10 | — | — | `max_retries` | integer | Hardcoded `3` | SMAC default; not in SAC source |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 12 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | Cast `timestamptz` → `timestamp` | SAC column quoted as `"created_at "` |
| 13 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not sourced from SAC `updated_at` |
| 14 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at` |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 16 | — | — | `audit_info` | jsonb | `'{}'::jsonb` | Empty audit object; SAC has no audit columns |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `updated_at` (quoted `"updated_at "`) — SMAC `updated_at` uses `NOW()` instead.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/contract_job_schedules_migration.sql`

## Validation

- Run `05-validation/crewing/contract_job_schedules_validation.sql` if available
- Run `06-rollback/crewing/contract_job_schedules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
