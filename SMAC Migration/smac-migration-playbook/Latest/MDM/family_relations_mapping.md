# Table Mapping: family_relations → family_relations

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: family_relations
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: family_relations
- **Source Script**: `04-migration-scripts/master/family_relations_migration.sql`

- **Legacy Path**: `synergy_master.public.family_relations`
- **New Path**: `smac_master_migration.public.family_relations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Family Relations (`family_relations` → `family_relations`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `gender_id` resolved by matching SAC `gender` (text) to `enum.gender.name` → `enum.gender.identifier` (UUID)
- `status` derived from `deleted_at`: NOT NULL → Deleted (3), else Active (0)
- `code` generated from `relation` + `uuid` via `generate_meaningful_code()` — no code column in SAC
- `status`, `workflow_status`, and `defined_by` use integer constants from `constants.sql`
- Filter: only rows where `TRIM(relation) <> ''` are migrated
- Pre-migration duplicate UUID check on SAC `uuid` column

## Special Considerations

- Script performs `TRUNCATE TABLE public.family_relations` before insert (full table reload)
- SAC has no audit columns — `audit_info` uses `SYSTEM_USER_ID` from `constants.sql`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `gender_id_mapping` | FK lookup | `new_gender_id`, `gender_name` | - | `synergy_master` |

### `gender_id_mapping`

- **Output columns**: new_gender_id, gender_name
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT DISTINCT
    d.identifier::uuid as new_gender_id,
    UPPER(TRIM(d.name)) as gender_name
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.gender WHERE identifier IS NOT NULL AND TRIM(COALESCE(name, '''')) <> '''''
) AS d(identifier uuid, name text)
WHERE d.identifier IS NOT NULL
  AND TRIM(COALESCE(d.name, '')) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `relation`, `uuid` | character varying, uuid | `code` | text | `generate_meaningful_code(TRIM(relation), uuid::text)` | Generated from relation name + uuid suffix; NOT NULL in SMAC |
| 3 | `relation` | character varying | `name` | text | `LEFT(INITCAP(TRIM(COALESCE(relation, 'UNKNOWN'))), 255)` | Title-cased display name; defaults to `'UNKNOWN'` when NULL; NOT NULL in SMAC |
| 4 | `gender` | character varying | `gender_id` | uuid | Match `UPPER(TRIM(gender))` to `gender_id_mapping.gender_name`; use `enum.gender.identifier` | Lookup: `gender_id_mapping` from `synergy_master.enum.gender` via dblink; nullable if no match |
| 5 | — | — | `category` | integer | Hardcoded `0` | NOT NULL in SMAC; no equivalent in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 10 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 — `deleted_at` is primary deletion indicator |
| 11 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 12 | `created_at` | timestamp(6) without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 13 | `updated_at` | timestamp(6) without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated (including deleted) |
| 15 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` for created/updated by | SAC has no audit columns; standardized SMAC structure; no `legacy_id` (uuid preserved as `id`) |

**SMAC columns not migrated:** `description`, `parent_id`, `archived_at`, `tags` — no source equivalent in SAC `family_relations`.

**SAC columns not migrated:** `identifier` — selected in dblink but not used; `uuid` is preserved as SMAC `id` instead.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Gender ID Mapping
**Output columns**: `new_gender_id, gender_name`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT DISTINCT
    d.identifier::uuid as new_gender_id,
    UPPER(TRIM(d.name)) as gender_name
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.gender WHERE identifier IS NOT NULL AND TRIM(COALESCE(name, '''')) <> '''''
) AS d(identifier uuid, name text)
WHERE d.identifier IS NOT NULL
  AND TRIM(COALESCE(d.name, '')) <> '';
```

Full migration context: `04-migration-scripts/master/family_relations_migration.sql`

## Validation

- Run `05-validation/master/family_relations_validation.sql` if available
- Run `06-rollback/master/family_relations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
