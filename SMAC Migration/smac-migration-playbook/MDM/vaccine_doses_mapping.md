# Table Mapping: vaccine_doses → vaccine_doses

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: vaccine_doses
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: vaccine_doses
- **Source Script**: `04-migration-scripts/master/vaccine_doses_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.vaccine_doses`
- **New Path**: `smac_master_migration.crewing.vaccine_doses`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vaccine Doses (`vaccine_doses` → `vaccine_doses`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- No duplicate UUID check needed as source table does not have identifier/uuid column
- Mappings in migration.table_mappings are managed automatically by migration.resolve_target_id()
- Migrates vaccine_doses table. Generates new UUIDs for id column (no identifier/uuid in source). Converts name (integer) to text. Stores legacy date and seafarer_covid19_id in audit_info. Uses standardized audit_info format.

## Special Considerations

- Generates new UUIDs for id (no identifier/uuid in source), converts name (integer) to text
- Script performs `TRUNCATE TABLE crewing.vaccine_doses` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'vaccine_doses'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(CAST(legacy_data.name AS text), NULL) |
| 3 | name | - | name | - | CAST(legacy_data.name AS text) as name | CAST(legacy_data.name AS text) |
| 4 | derived | - | description | - | NULL as description | NULL |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 7 | derived | - | level | - | NULL as level | NULL |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | derived | - | status | - | 0 as status | 0 |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 14 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 15 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 16 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND TRIM(legacy_data.created_by_id::text) <> '' AND TRIM(legacy_data.created_by_id::text) ~* '^[0-9a-... |
| 17 | derived | - | tags | - | NULL as tags | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vaccine_doses_migration.sql`

## Validation

- Run `05-validation/master/vaccine_doses_validation.sql` if available
- Run `06-rollback/master/vaccine_doses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
