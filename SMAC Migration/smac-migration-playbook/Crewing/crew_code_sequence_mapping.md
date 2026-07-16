# Table Mapping: crewcode → crew_code_sequence

## Overview
- **Legacy Database**: crew-code-db
- **Legacy Schema**: public
- **Legacy Table**: crewcode
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crew_code_sequence
- **Source Script**: `04-migration-scripts/crewing/crew_code_sequence_migration.sql`

- **Legacy Path**: `crew-code-db.public.crewcode`
- **New Path**: `smac_crewing_migration.public.crew_code_sequence`

## Business Key

- **Business Key**: `country_code`
- **Source (orchestration)**: Crew Code Sequence (`crewcode` → `crew_code_sequence`)

## Migration Notes

- Source table has no identifier/uuid column, uses migration.resolve_target_id() for idempotent UUID generation
- Group by nationality: one target record per unique nationality
- Map nationality → country_code
- Map MAX(codenumber) per nationality → last_sequence (maximum sequence number for each country)
- Uses centralized migration utilities for ID mapping and idempotency
- Migrates crewcode to crew_code_sequence table. Generates new UUIDs for id column (source has integer IDENTITY, target has uuid). Maps code to country_code, codenumber to last_sequence. Filters out records with empty code values. Stores legacy crewcodeid in audit_info->>'legacy_id'. No foreign key dependencies. Uses standardized SMAC audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crew_code_sequence` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | source_id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'crew-code-db'::VARCHAR(100), 'public'::VARCHAR(100), 'crewcode'::VARCHAR(100), s.source_id, current_database()::text::VARCHAR(100), 'public'::VARCH... |
| 2 | country_code | - | country_code | - | s.country_code AS country_code | s.country_code |
| 3 | last_sequence | - | last_sequence | - | s.last_sequence AS last_sequence | s.last_sequence |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | created_at | - | now() AS created_at | now() |
| 6 | derived | - | updated_at | - | now() AS updated_at | now() |
| 7 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 8 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 9 | source_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN s.sou... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/crew_code_sequence_migration.sql`

## Validation

- Run `05-validation/crewing/crew_code_sequence_validation.sql` if available
- Run `06-rollback/crewing/crew_code_sequence_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
