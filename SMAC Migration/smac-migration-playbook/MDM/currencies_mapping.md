# Table Mapping: currencies → currencies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: currencies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: currencies
- **Source Script**: `04-migration-scripts/master/currencies_migration.sql`

- **Legacy Path**: `synergy_master.public.currencies`
- **New Path**: `smac_master_migration.public.currencies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Currencies (`currencies` → `currencies`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- currencies table does not have uuid/identifier column, so skip duplicate UUID check

## Special Considerations

- Script performs `TRUNCATE TABLE public.currencies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'currencies'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'p... |
| 2 | code | - | code | - | TRIM(legacy_data.code) as code | TRIM(legacy_data.code) |
| 3 | code | - | name | - | COALESCE(cnm.name, UPPER(TRIM(legacy_data.code))) as name | COALESCE(cnm.name, UPPER(TRIM(legacy_data.code))) |
| 4 | derived | - | symbol | - | NULL as symbol | NULL |
| 5 | is_cba_currency | - | is_contract_currency | - | COALESCE(legacy_data.is_cba_currency, false) as is_contract_currency | COALESCE(legacy_data.is_cba_currency, false) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | derived | - | level | - | 0 as level | 0 |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | is_cba_currency | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 16 | code | - | tags | - | ARRAY( SELECT DISTINCT t FROM unnest(ARRAY[ TRIM(legacy_data.code), LOWER(COALESCE(cnm.name, UPPER(TRIM(legacy_data.code)))) ]) t WHERE t IS NOT NULL AND TRIM(t) <> '' )::text[]... | ARRAY( SELECT DISTINCT t FROM unnest(ARRAY[ TRIM(legacy_data.code), LOWER(COALESCE(cnm.name, UPPER(TRIM(legacy_data.code)))) ]) t WHERE t IS NOT NULL AND TRIM(t) <> '' )::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/currencies_migration.sql`

## Validation

- Run `05-validation/master/currencies_validation.sql` if available
- Run `06-rollback/master/currencies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
