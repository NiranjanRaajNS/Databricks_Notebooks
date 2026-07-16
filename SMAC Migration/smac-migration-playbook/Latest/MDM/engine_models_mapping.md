# Table Mapping: engine_model → engine_models

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: engine_model
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: engine_models
- **Source Script**: `04-migration-scripts/master/engine_models_migration.sql`

- **Legacy Path**: `synergy_vessel.public.engine_model`
- **New Path**: `smac_master_migration.vessel.engine_models`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Engine Model (`engine_model` → `engine_models`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier` (identifier is PK in SAC)
- `code` generated via `generate_meaningful_code(COALESCE(TRIM(name), 'UNKNOWN'), identifier::text)`
- `engine_make_id` mapped via `engine_make_id_mapping` (`migration.table_mappings` where `target_table = 'engine_makes'`)
- `description` strips HTML `<p>`/`</p>` tags from SAC text
- `status` derived from `deleted_at` + `status` varchar (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Filter: `identifier IS NOT NULL`, non-empty name, valid `engine_make_id` FK mapping
- Duplicate UUID check commented out (identifier is PK)
- Requires `engine_makes` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.engine_models` before insert (full table reload).
- Orchestration dependencies: `engine_makes`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `engine_make_id_mapping` | Check for duplicate UUIDs in source table | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `engine_make_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=engine_makes

```sql
CREATE TEMP TABLE engine_make_id_mapping AS
SELECT
    source_id::text AS source_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'engine_makes'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; identifier is SAC primary key |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(COALESCE(TRIM(name), 'UNKNOWN'), identifier::text)` | Generated from trimmed name + identifier; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `COALESCE(TRIM(name), 'UNKNOWN')` | Direct copy with trim; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `NULLIF(TRIM(REGEXP_REPLACE(COALESCE(description, ''), '</?p>', '', 'gi')), '')` | Strips HTML `<p>` tags; NULL when empty after cleanup |
| 5 | `engine_make_id` | bigint | `engine_make_id` | uuid | Map via `engine_make_id_mapping`; join on `source_id = engine_make_id::text` | Lookup: `migration.table_mappings` where `target_table = 'engine_makes'` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 14 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

**SMAC columns not migrated:** `parent_id`, `archived_at`, `tags` — no source equivalent in SAC `engine_model`.

**SAC columns not migrated:** `id` (bigint), `audit_info` (jsonb) — SAC bigint `id` used only as mapping source_id when applicable; audit JSONB not mapped to SMAC fields.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `engine_makes`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Engine Make ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `target_table='engine_makes'`

```sql
CREATE TEMP TABLE engine_make_id_mapping AS
SELECT
    source_id::text AS source_id,
    target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'engine_makes'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/engine_models_migration.sql`

## Validation

- Run `05-validation/master/engine_models_validation.sql` if available
- Run `06-rollback/master/engine_models_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
