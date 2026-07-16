# Table Mapping: proficiency_levels → language_proficiencies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: proficiency_levels
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: language_proficiencies
- **Source Script**: `04-migration-scripts/master/language_proficiencies_migration.sql`

- **Legacy Path**: `synergy_master.enum.proficiency_levels`
- **New Path**: `smac_master_migration.public.language_proficiencies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Proficiency Levels (`proficiency_levels` → `language_proficiencies`)

## Migration Notes

- Preserve legacy identifier (UUID) as id (use legacy identifier directly as the new id)
- Record legacy id (integer) → new uuid (identifier) in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.language_proficiencies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'proficiency_levels'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | label, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.label), TRIM(legacy_data.identifier::text)) |
| 3 | label | - | name | - | COALESCE(TRIM(legacy_data.label), 'UNKNOWN') AS name | COALESCE(TRIM(legacy_data.label), 'UNKNOWN') |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 AS version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | 0 AS status | 0 |
| 9 | derived | - | level | - | 0 AS level | 0 |
| 10 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/language_proficiencies_migration.sql`

## Validation

- Run `05-validation/master/language_proficiencies_validation.sql` if available
- Run `06-rollback/master/language_proficiencies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
