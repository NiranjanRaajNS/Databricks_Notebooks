# Table Mapping: vdr_make → vdr_makes

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vdr_make
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vdr_makes
- **Source Script**: `04-migration-scripts/master/vdr_makes_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vdr_make`
- **New Path**: `smac_master_migration.vessel.vdr_makes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vdr Make (`vdr_make` → `vdr_makes`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`; source_id = `identifier::text` (no bigint `id` column)
- `DISTINCT ON (identifier)` deduplicates source rows
- Filter: `identifier IS NOT NULL` and non-empty `name`
- No `deleted_at` in SAC — all Active (`status = 0`)
- Duplicate UUID check on `identifier` is commented out in script

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vdr_makes` before insert (full table reload)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id` |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(COALESCE(TRIM(name), 'UNKNOWN'), identifier::text)` | Generated business code |
| 3 | `name` | text | `name` | text | `COALESCE(TRIM(name), 'UNKNOWN')` | Defaults to `'UNKNOWN'` when name empty |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 5 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 8 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in SAC source |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 12 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vdr_makes_migration.sql`

## Validation

- Run `05-validation/master/vdr_makes_validation.sql` if available
- Run `06-rollback/master/vdr_makes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
