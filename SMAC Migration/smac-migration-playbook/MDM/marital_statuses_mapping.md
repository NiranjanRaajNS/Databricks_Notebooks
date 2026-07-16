# Table Mapping: marital_status_options → marital_statuses

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: marital_status_options
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: marital_statuses
- **Source Script**: `04-migration-scripts/master/marital_statuses_migration.sql`

- **Legacy Path**: `synergy_master.enum.marital_status_options`
- **New Path**: `smac_master_migration.public.marital_statuses`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Marital Status Options (`marital_status_options` → `marital_statuses`)

## Migration Notes

- Preserve legacy identifier (UUID) as id
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates marital_status_options preserving identifier UUID as id

## Special Considerations

- Script performs `TRUNCATE TABLE public.marital_statuses` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id, legacy_uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'marital_status_options'::VARCHAR(100), s.legacy_id::text, current_database()::text::VARCHAR(1... |
| 2 | status_name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(s.status_name), NULL) |
| 3 | status_name | - | name | - | COALESCE(s.status_name, 'UNKNOWN') AS name | COALESCE(s.status_name, 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 10 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 11 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 12 | derived | - | level | - | 0 AS level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/marital_statuses_migration.sql`

## Validation

- Run `05-validation/master/marital_statuses_validation.sql` if available
- Run `06-rollback/master/marital_statuses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
