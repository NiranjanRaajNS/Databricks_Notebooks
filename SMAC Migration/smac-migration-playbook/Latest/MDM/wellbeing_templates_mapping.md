# Table Mapping: wellbeing_templates → wellbeing_templates

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: wellbeing_templates
- **Source Script**: `04-migration-scripts/master/wellbeing_templates_migration.sql`

- **New Path**: `smac_master_migration.crewing.wellbeing_templates`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Wellbeing Templates (`wellbeing_templates` → `wellbeing_templates`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `name`/`code` derived from `template` JSONB keys (`name`, `title`, `label`)
- `applicable_rank_ids` converted from SAC bigint text[] to SMAC uuid[] via `rank_sac_to_smac_uuid`
- `status` derived from `deleted_at` using `STATUS_DELETED`/`STATUS_ACTIVE` constants
- `tags` from generated code
## Special Considerations

- Script performs `TRUNCATE TABLE crewing.wellbeing_templates` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `rank_sac_to_smac_uuid` | FK lookup | `tm.source_id`, `tm.target_id` | `synergy_master.public.ranks` → `?.public.ranks` | - |

### `rank_sac_to_smac_uuid`

- **Output columns**: tm.source_id, tm.target_id
- **migration.table_mappings**: source_db=synergy_master, source_schema=public, source_table=ranks, target_schema=public, target_table=ranks

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
SELECT
    tm.source_id,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.target_db = current_database()
  AND tm.target_schema = 'public'
  AND tm.target_table = 'ranks'
  AND tm.source_db = 'synergy_master'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'ranks';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `template` | jsonb | `name` | text | Extract from `template->>'name'` / `title` / `label` with fallback | Derived from JSONB |
| 3 | `template, id` | jsonb, uuid | `code` | text | `generate_meaningful_code(display_name, id::text)` | Generated from derived name |
| 4 | `template` | jsonb | `description` | text | Extract from `template->>'description'` when present | Derived from JSONB |
| 5 | `template` | jsonb | `template` | jsonb | `COALESCE(template, '{}'::jsonb)` | Full template JSON preserved |
| 6 | `applicable_rank_ids` | text[] | `applicable_rank_ids` | uuid[] | Map each SAC rank id text → uuid via `rank_sac_to_smac_uuid` | FK lookup via table_mappings |
| 7 | `version` | integer | `version` | integer | `COALESCE(version, 1)` | Direct copy with default |
| 8 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → STATUS_DELETED; else STATUS_ACTIVE | Uses constants.sql status values |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 12 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 13 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 15 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 16 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 17 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 18 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |
| 19 | `code` | text | `tags` | text[] | Array from generated code | Derived search tag |

**SAC columns not migrated:** None from dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Rank Sac To Smac Uuid ID Mapping
**Output columns**: `tm.source_id, tm.target_id`
**migration.table_mappings**: `ranks` → `ranks` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
SELECT
    tm.source_id,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.target_db = current_database()
  AND tm.target_schema = 'public'
  AND tm.target_table = 'ranks'
  AND tm.source_db = 'synergy_master'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'ranks';
```

Full migration context: `04-migration-scripts/master/wellbeing_templates_migration.sql`

## Validation

- Run `05-validation/master/wellbeing_templates_validation.sql` if available
- Run `06-rollback/master/wellbeing_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
