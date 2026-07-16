# Table Mapping: cbas → cbas

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cbas
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cbas
- **Source Script**: `04-migration-scripts/master/cbas_migration.sql`

- **Legacy Path**: `synergy_master.public.cbas`
- **New Path**: `smac_master_migration.crewing.cbas`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cbas (`cbas` → `cbas`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.cbas` before insert (full table reload).
- Orchestration dependencies: `cba_types`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'cbas'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'crewing... |
| 2 | code | - | code | - | UPPER(TRIM(legacy_data.code)) as code | UPPER(TRIM(legacy_data.code)) |
| 3 | name | - | name | - | UPPER(TRIM(legacy_data.name)) as name | UPPER(TRIM(legacy_data.name)) |
| 4 | derived | - | cba_type_id | - | cba_types_lookup.id as cba_type_id | cba_types_lookup.id |
| 5 | derived | - | currency_id | - | currency_lookup.id as currency_id | currency_lookup.id |
| 6 | description | - | description | - | CASE WHEN legacy_data.description IS NULL THEN NULL WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END as description | CASE WHEN legacy_data.description IS NULL THEN NULL WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END |
| 7 | include_superior_certificate | - | include_superior_certificate | - | COALESCE(legacy_data.include_superior_certificate, false) as include_superior_certificate | COALESCE(legacy_data.include_superior_certificate, false) |
| 8 | nationality | - | is_all_nationalities | - | CASE WHEN legacy_data.nationality IS NULL THEN false WHEN TRIM(legacy_data.nationality::text) = '["ALL"]' THEN true WHEN legacy_data.nationality @> '["ALL"]'::jsonb THEN true EL... | CASE WHEN legacy_data.nationality IS NULL THEN false WHEN TRIM(legacy_data.nationality::text) = '["ALL"]' THEN true WHEN legacy_data.nationality @> '["ALL"]'::jsonb THEN true EL... |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | version | - | 1 as version | 1 |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | derived | - | level | - | 0 as level | 0 |
| 15 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 16 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 17 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 18 | created_by_id, updated_by_id | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cba_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/cbas_migration.sql`

## Validation

- Run `05-validation/master/cbas_validation.sql` if available
- Run `06-rollback/master/cbas_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
