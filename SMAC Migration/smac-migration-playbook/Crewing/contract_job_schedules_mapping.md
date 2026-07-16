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

- Only migrates rows where "status " = 'Scheduled' (status column has trailing space)
- Migrates scheduled_job to contract_job_schedules. Preserves UUID as id. Maps job_identifier to job_code, meta_data to job_payload, scheduled_at to scheduled_for. Converts timestamptz to timestamp. Sets default values for retry_count (0) and max_retries (3).

## Special Considerations

- Script performs `TRUNCATE TABLE shore.contract_job_schedules` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'scheduled_job'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100)... |
| 2 | job_identifier | - | job_code | - | TRIM(legacy_data.job_identifier) AS job_code | TRIM(legacy_data.job_identifier) |
| 3 | meta_data | - | job_payload | - | COALESCE(legacy_data.meta_data, '{}'::jsonb) AS job_payload | COALESCE(legacy_data.meta_data, '{}'::jsonb) |
| 4 | scheduled_at | - | scheduled_for | - | CAST(legacy_data.scheduled_at AS timestamp) AS scheduled_for | CAST(legacy_data.scheduled_at AS timestamp) |
| 5 | type | - | job_type | - | TRIM(legacy_data.type) AS job_type | TRIM(legacy_data.type) |
| 6 | status | - | job_status | - | COALESCE(TRIM(legacy_data.status), 'pending') AS job_status | COALESCE(TRIM(legacy_data.status), 'pending') |
| 7 | - | - | last_run_at | - | NULL | NULL::timestamp |
| 8 | - | - | next_run_at | - | NULL | NULL::timestamp |
| 9 | derived | - | retry_count | - | 0 AS retry_count | 0 |
| 10 | derived | - | max_retries | - | 3 AS max_retries | 3 |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | created_at | - | created_at | - | CAST(legacy_data.created_at AS timestamp) AS created_at | CAST(legacy_data.created_at AS timestamp) |
| 13 | derived | - | updated_at | - | NOW()::timestamp AS updated_at | NOW()::timestamp |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | derived | - | audit_info | - | '{}'::jsonb AS audit_info | '{}'::jsonb |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/contract_job_schedules_migration.sql`

## Validation

- Run `05-validation/crewing/contract_job_schedules_validation.sql` if available
- Run `06-rollback/crewing/contract_job_schedules_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
