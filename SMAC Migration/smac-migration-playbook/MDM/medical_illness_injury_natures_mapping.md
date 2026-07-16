# Table Mapping: medical_event_nature → medical_illness_injury_natures

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: medical_event_nature
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: medical_illness_injury_natures
- **Source Script**: `04-migration-scripts/master/medical_illness_injury_natures_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.medical_event_nature`
- **New Path**: `smac_master_migration.crewing.medical_illness_injury_natures`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Medical Illness Injury Natures (`medical_event_nature` → `medical_illness_injury_natures`)

## Migration Notes

- Uses migration.resolve_target_id() to preserve legacy UUID id (with idempotency support)
- Generate code from name (no UUID suffix)
- Map nature_order → level
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates medical_event_nature to medical_illness_injury_natures table. Preserves legacy UUID id directly. Generates code from name (no UUID suffix). Maps nature_order → level. Uses standardized SMAC audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.medical_illness_injury_natures` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'medical_event_nature'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARC... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') AS name | COALESCE(TRIM(legacy_data.name), 'UNKNOWN') |
| 4 | derived | - | description | - | NULL AS description | NULL |
| 5 | nature_order | - | level | - | COALESCE(legacy_data.nature_order, 0) AS level | COALESCE(legacy_data.nature_order, 0) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 AS status | 0 |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/medical_illness_injury_natures_migration.sql`

## Validation

- Run `05-validation/master/medical_illness_injury_natures_validation.sql` if available
- Run `06-rollback/master/medical_illness_injury_natures_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
