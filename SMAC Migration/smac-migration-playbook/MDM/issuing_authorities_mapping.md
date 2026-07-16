# Table Mapping: issuing_authorities → issuing_authorities

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: issuing_authorities
- **Source Script**: `04-migration-scripts/master/issuing_authorities_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.seafarer_documents.issuing_authority`
- **New Path**: `smac_master_migration.document.issuing_authorities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Issuing Authorities (`document_issuing_authorities` → `issuing_authorities`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- No duplicate UUID check needed - source table has no UUID/identifier column
- Migrates document_issuing_authorities preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Extracts distinct issuing_authority values and maps to states/countries
- Script performs `TRUNCATE TABLE document.issuing_authorities` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | resolved.id | resolved.id |
| 2 | derived | - | code | - | resolved.code | resolved.code |
| 3 | derived | - | name | - | resolved.name | resolved.name |
| 4 | derived | - | description | - | resolved.description | resolved.description |
| 5 | derived | - | country_id | - | COALESCE( resolved.country_id_from_state, (SELECT country_id FROM default_country), NULL ) as country_id | COALESCE( resolved.country_id_from_state, (SELECT country_id FROM default_country), NULL ) |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 as version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 as status | 0 |
| 11 | derived | - | level | - | 0 as level | 0 |
| 12 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 13 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 14 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/issuing_authorities_migration.sql`

## Validation

- Run `05-validation/master/issuing_authorities_validation.sql` if available
- Run `06-rollback/master/issuing_authorities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
