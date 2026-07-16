# Table Mapping: non_synergy_group_companies → non_synergy_group_companies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: non_synergy_group_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: non_synergy_group_companies
- **Source Script**: `04-migration-scripts/master/non_synergy_group_companies_migration.sql`

- **Legacy Path**: `synergy_master.public.non_synergy_group_companies`
- **New Path**: `smac_master_migration.public.non_synergy_group_companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Special Considerations

- Script performs `TRUNCATE TABLE public.non_synergy_group_companies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'non_synergy_group_companies'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | name | - | TRIM(name) as name | TRIM(name) |
| 3 | derived | - | code | - | generate_meaningful_code() | COALESCE(NULLIF(TRIM(code), ''), generate_meaningful_code(TRIM(name), NULL)) |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 as status | 0 |
| 9 | derived | - | created_at | - | COALESCE(created_at, NOW()) as created_at | COALESCE(created_at, NOW()) |
| 10 | derived | - | updated_at | - | COALESCE(updated_at, NOW()) as updated_at | COALESCE(updated_at, NOW()) |
| 11 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by::varchar, NULL::varchar, legacy_data.updated_by::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::... |
| 12 | derived | - | level | - | 0 AS level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/non_synergy_group_companies_migration.sql`

## Validation

- Run `05-validation/master/non_synergy_group_companies_validation.sql` if available
- Run `06-rollback/master/non_synergy_group_companies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
