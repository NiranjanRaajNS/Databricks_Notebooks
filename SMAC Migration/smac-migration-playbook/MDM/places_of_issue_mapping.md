# Table Mapping: places_of_issue → places_of_issue

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: places_of_issue
- **Source Script**: `04-migration-scripts/master/places_of_issue_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.seafarer_documents.place_of_issue`
- **New Path**: `smac_master_migration.document.places_of_issue`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Documents (`seafarer_documents` → `places_of_issue`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Extracts distinct place_of_issue values from seafarer_documents.place_of_issue column and creates master table. Generates new UUIDs for each distinct place.

## Special Considerations

- Extracts distinct place_of_issue values and maps to states/countries
- Script performs `TRUNCATE TABLE document.places_of_issue` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | code | - | LEFT(COALESCE(staging.place_of_issue, 'UNKNOWN'), 100)::varchar(100) as code | LEFT(COALESCE(staging.place_of_issue, 'UNKNOWN'), 100)::varchar(100) |
| 3 | derived | - | name | - | LEFT(staging.place_of_issue, 100)::varchar(100) as name | LEFT(staging.place_of_issue, 100)::varchar(100) |
| 4 | derived | - | country_id | - | COALESCE(staging.country_id_from_state, (SELECT country_id FROM default_country), NULL) as country_id | COALESCE(staging.country_id_from_state, (SELECT country_id FROM default_country), NULL) |
| 5 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | derived | - | defined_by | - | 0 as defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 9 | derived | - | status | - | CASE WHEN staging.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN staging.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | derived | - | created_at | - | COALESCE(staging.created_at, NOW()) as created_at | COALESCE(staging.created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(staging.updated_at, NOW()) as updated_at | COALESCE(staging.updated_at, NOW()) |
| 12 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL, NULL, NULL, NULL, NULL, NULL, CASE WHEN (staging.created_by_name IS NOT ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/places_of_issue_migration.sql`

## Validation

- Run `05-validation/master/places_of_issue_validation.sql` if available
- Run `06-rollback/master/places_of_issue_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
