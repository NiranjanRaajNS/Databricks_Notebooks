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

- Source has no UUID column — `migration.resolve_target_id()` with `p_target_id = NULL` (idempotent via `id_mappings`)
- Aggregates SAC rows: one SMAC row per distinct `nationality` (first 10 chars → `country_code`)
- `last_sequence` = `MAX(codenumber)` per nationality; only groups with `last_sequence > 0` migrated
- `source_id` for mapping = comma-aggregated `crewcodeid` values per group (stored in audit `notes`)
- No foreign key dependencies

## Special Considerations

- Script performs `TRUNCATE TABLE public.crew_code_sequence` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `crewcodeid` (aggregated) | integer | `id` | uuid | `migration.resolve_target_id()` — source_id = aggregated `crewcodeid` list; `p_target_id = NULL` | One UUID per nationality group; idempotent |
| 2 | `nationality` | character varying(20) | `country_code` | character varying(10) | `LEFT(TRIM(nationality), 10)` per group | Grouped key; NOT NULL |
| 3 | `codenumber` | bigint | `last_sequence` | bigint | `MAX(codenumber)` per nationality group | Only groups with max > 0 migrated |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 5 | — | — | `created_at` | timestamp without time zone | `now()` | No `created_at` in SAC |
| 6 | — | — | `updated_at` | timestamp without time zone | `now()` | No `updated_at` in SAC |
| 7 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 8 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no soft-delete |
| 9 | `crewcodeid` (aggregated) | integer | `audit_info` | jsonb | `migration.build_audit_info()` — aggregated IDs in `notes` | - |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `code` — not referenced in migration script; individual `crewcodeid` rows collapsed into per-nationality aggregates.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/crew_code_sequence_migration.sql`

## Validation

- Run `05-validation/crewing/crew_code_sequence_validation.sql` if available
- Run `06-rollback/crewing/crew_code_sequence_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
