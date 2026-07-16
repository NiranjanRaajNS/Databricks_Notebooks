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

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Same source table `medical_event_nature` as `medical_event_natures` migration (separate target table)
- `code` generated from `name` via `generate_meaningful_code(TRIM(name), NULL)`
- `nature_order` mapped to SMAC `level` via `COALESCE(nature_order, 0)`
- `status` hardcoded Active (0); SAC has no `deleted_at` column
- Filter: `id IS NOT NULL` in SAC source
- Pre-migration duplicate UUID check on SAC `id` column

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.medical_illness_injury_natures` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` | Generated from name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `COALESCE(TRIM(name), 'UNKNOWN')` | Direct copy with fallback; NOT NULL in SMAC |
| 4 | — | — | `description` | text | Hardcoded NULL | No description in SAC source |
| 5 | `nature_order` | bigint | `level` | numeric | `COALESCE(nature_order, 0)` | SAC hierarchy order mapped to SMAC `level` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC has no `deleted_at` column |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |

**SMAC columns not migrated:** `deleted_at`, `parent_id`, `archived_at`, `tags` — no source equivalent in SAC `medical_event_nature`.

**SAC columns not migrated:** `audit_info` — present in source dblink but not used in migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/medical_illness_injury_natures_migration.sql`

## Validation

- Run `05-validation/master/medical_illness_injury_natures_validation.sql` if available
- Run `06-rollback/master/medical_illness_injury_natures_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
