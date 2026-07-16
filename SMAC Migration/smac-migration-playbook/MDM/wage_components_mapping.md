# Table Mapping: basic_wage_components → wage_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: basic_wage_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: wage_components
- **Source Script**: `04-migration-scripts/master/wage_components_migration.sql`

- **Legacy Path**: `synergy_master.wages.basic_wage_components`
- **New Path**: `smac_master_migration.crewing.wage_components`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Wage Components (`basic_wage_components` → `wage_components`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates basic_wage_components from synergy_master.wages preserving UUID id. Maps type (Earning=1, Deduction=2) and payment_frequency (Monthly=1, OneTime=2) to integer enums. Status mapped from deleted_at timestamp.

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.wage_components` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'wages'::VARCHAR(100), 'basic_wage_components'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(legacy_data.name, legacy_data.identifier) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | derived | - | level | - | 0 as level | 0 |
| 6 | type | - | type | - | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.type, ''))) = 'EARNING' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.type, ''))) = 'DEDUCTION' THEN 2 ELSE 1 END as type | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.type, ''))) = 'EARNING' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.type, ''))) = 'DEDUCTION' THEN 2 ELSE 1 END |
| 7 | payment_frequency | - | payment_frequency | - | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.payment_frequency, ''))) = 'MONTHLY' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.payment_frequency, ''))) = 'ONETIME' OR UPPER(REPLACE(... | CASE WHEN UPPER(TRIM(COALESCE(legacy_data.payment_frequency, ''))) = 'MONTHLY' THEN 1 WHEN UPPER(TRIM(COALESCE(legacy_data.payment_frequency, ''))) = 'ONETIME' OR UPPER(REPLACE(... |
| 8 | account_code | - | account_code | - | TRIM(legacy_data.account_code) as account_code | TRIM(legacy_data.account_code) |
| 9 | is_optional | - | is_optional | - | COALESCE(legacy_data.is_optional, false) as is_optional | COALESCE(legacy_data.is_optional, false) |
| 10 | derived | - | is_system_defined | - | false as is_system_defined | false |
| 11 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 12 | derived | - | version | - | 1 as version | 1 |
| 13 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 14 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 15 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 16 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 17 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 18 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 19 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 20 | created_by, updated_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/wage_components_migration.sql`

## Validation

- Run `05-validation/master/wage_components_validation.sql` if available
- Run `06-rollback/master/wage_components_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
