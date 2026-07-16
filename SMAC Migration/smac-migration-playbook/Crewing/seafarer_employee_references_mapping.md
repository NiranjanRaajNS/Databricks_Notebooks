# Table Mapping: seafarer_employee_reference → seafarer_employee_references

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_employee_reference
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_employee_references
- **Source Script**: `04-migration-scripts/crewing/seafarer_employee_references_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_employee_reference`
- **New Path**: `smac_crewing_migration.shore.seafarer_employee_references`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Employee References (`seafarer_employee_reference` → `seafarer_employee_references`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- seafarer_id is UUID in source and can be used directly (no mapping needed)
- Migrates seafarer_employee_reference to seafarer_employee_references table. Preserves legacy identifier UUID when available. Maps seafarer_id (bigint) to uuid via migration.table_mappings. Requires seafarers table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_employee_references` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_employee_reference'::VARCHAR(100), legacy_data_cte.id::text, current_database():... |
| 2 | - | - | seafarer_id | - | CASE WHEN legacy_data_cte.seafarer_id_text IS NULL OR legacy_data_cte.seafarer_id_text = '' THEN NULL::uuid WHEN legacy_data_cte.seafarer_id_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-... | CASE WHEN legacy_data_cte.seafarer_id_text IS NULL OR legacy_data_cte.seafarer_id_text = '' THEN NULL::uuid WHEN legacy_data_cte.seafarer_id_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-... |
| 3 | - | - | referred_by_id | - | NULL | NULL::uuid |
| 4 | derived | - | referred_by_name | - | TRIM(legacy_data_cte.referred_by) as referred_by_name | TRIM(legacy_data_cte.referred_by) |
| 5 | - | - | employer_id | - | NULL | NULL::uuid |
| 6 | derived | - | employer_name | - | TRIM(legacy_data_cte.employer) as employer_name | TRIM(legacy_data_cte.employer) |
| 7 | derived | - | contact_person | - | TRIM(legacy_data_cte.pic_contact) as contact_person | TRIM(legacy_data_cte.pic_contact) |
| 8 | derived | - | contact_email | - | TRIM(legacy_data_cte.email) as contact_email | TRIM(legacy_data_cte.email) |
| 9 | derived | - | contact_phone | - | TRIM(legacy_data_cte.phone_number) as contact_phone | TRIM(legacy_data_cte.phone_number) |
| 10 | derived | - | conduct_rating | - | TRIM(legacy_data_cte.conduct) as conduct_rating | TRIM(legacy_data_cte.conduct) |
| 11 | - | - | remarks | - | NULL | NULL::text |
| 12 | derived | - | workflow_status_id | - | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) as workflow_status_id | (SELECT workflow_status_id FROM approved_workflow_status LIMIT 1) |
| 13 | derived | - | status | - | 'active'::text as status | 'active'::text |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | derived | - | created_at | - | COALESCE(legacy_data_cte.created_at, NOW()) as created_at | COALESCE(legacy_data_cte.created_at, NOW()) |
| 16 | derived | - | updated_at | - | COALESCE(legacy_data_cte.updated_at, NOW()) as updated_at | COALESCE(legacy_data_cte.updated_at, NOW()) |
| 17 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_employee_references_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_employee_references_validation.sql` if available
- Run `06-rollback/crewing/seafarer_employee_references_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
