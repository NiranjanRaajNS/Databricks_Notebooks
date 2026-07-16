# Table Mapping: "Ranks" → ranks

## Overview
- **Legacy Database**: IdentityAdmin_prod
- **Legacy Schema**: public
- **Legacy Table**: "Ranks"
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: ranks
- **Source Script**: `04-migration-scripts/idp/seafarer/ranks_migration.sql`

- **Legacy Path**: `IdentityAdmin_prod.public."Ranks"`
- **New Path**: `smac_idp_dev.public.ranks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (Seafarer) (`Ranks` → `ranks`)

## Migration Notes

- This migration is for seafarer rank information from IdentityAdmin_prod database.
- Adjust based on actual source schema discovered via inspect_ranks_schema.sql
- Migrates seafarer ranks from IdentityAdmin_prod database. Separate from shore ranks migration. Uses seafarer subfolder for migration scripts.

## Special Considerations

- Script performs `TRUNCATE TABLE public.ranks` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id_text | - | id | - | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Ranks'::VARCHAR(100), legacy_data.id_text, current_database()::text::VARCHAR(100), 'pu... | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Ranks'::VARCHAR(100), legacy_data.id_text, current_database()::text::VARCHAR(100), 'pu... |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | derived | - | level | - | NULL as level | NULL |
| 4 | derived | - | superior_rank_id | - | NULL as superior_rank_id | NULL |
| 5 | derived | - | is_lowest_rank | - | false as is_lowest_rank | false |
| 6 | name | - | code | - | LEFT( UPPER( REPLACE( REGEXP_REPLACE( TRIM(legacy_data.name), '[^A-Za-z0-9 ]', '', 'g' ), ' ', '_' ) ), 10 ) as code | LEFT( UPPER( REPLACE( REGEXP_REPLACE( TRIM(legacy_data.name), '[^A-Za-z0-9 ]', '', 'g' ), ' ', '_' ) ), 10 ) |
| 7 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 8 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 9 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 10 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 11 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 12 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 13 | derived | - | status | - | 0 as status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/seafarer/ranks_migration.sql`

## Validation

- Run `05-validation/idp/ranks_validation.sql` if available
- Run `06-rollback/idp/ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
