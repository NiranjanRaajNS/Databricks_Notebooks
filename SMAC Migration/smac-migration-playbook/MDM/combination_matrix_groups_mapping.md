# Table Mapping: rank_combination_groups → combination_matrix_groups

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combination_groups
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: combination_matrix_groups
- **Source Script**: `04-migration-scripts/master/combination_matrix_groups_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combination_groups`
- **New Path**: `smac_master_migration.crewing.combination_matrix_groups`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Combination Matrix Groups (`rank_combination_groups` → `combination_matrix_groups`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates rank_combination_groups to combination_matrix_groups. Uses migration.resolve_target_id() for idempotent UUID generation. Maps is_active boolean and deleted_at to status integer (Case 3 pattern). Generates code from name if not available. Uses standardized SMAC audit_info structure with legacy_id. Master table with no dependencies.

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Script performs `TRUNCATE TABLE crewing.combination_matrix_groups` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'rank_combination_groups'::VARCHAR(100), legacy_data.id::text, current_database()::text::VAR... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | CASE WHEN legacy_data.description IS NULL THEN NULL WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END as description | CASE WHEN legacy_data.description IS NULL THEN NULL WHEN TRIM(legacy_data.description) = '' THEN NULL ELSE TRIM(legacy_data.description) END |
| 5 | is_doc_combination | - | is_doc_combination | - | COALESCE(legacy_data.is_doc_combination, false) as is_doc_combination | COALESCE(legacy_data.is_doc_combination, false) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | created_by, updated_by, deleted_by | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/combination_matrix_groups_migration.sql`

## Validation

- Run `05-validation/master/combination_matrix_groups_validation.sql` if available
- Run `06-rollback/master/combination_matrix_groups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
