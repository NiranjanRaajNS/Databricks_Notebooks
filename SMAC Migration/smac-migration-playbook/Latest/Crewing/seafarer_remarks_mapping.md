# Table Mapping: seafarer_remarks → seafarer_remarks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_remarks
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_remarks
- **Source Script**: `04-migration-scripts/crewing/seafarer_remarks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_remarks`
- **New Path**: `smac_crewing_migration.shore.seafarer_remarks`

## Business Key

- **Composite Key**: (`id`, array ordinality) — SAC `id` + position within `profile_remark` JSONB array
- **Source (orchestration)**: Seafarer Remarks (`seafarer_remarks` → `seafarer_remarks`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- SAC `profile_remark` JSONB array is unnested — one SMAC row per array element (`jsonb_array_elements` with ordinality)
- Only records where `profile_remark` is a non-empty JSONB array are migrated
- `remark_type` in array elements maps to `profile_remark_type_id` via `crewing.profile_remark_types` (LOWER name match; `Inactive` → `deactivation`, `Active` → `activation`)
- `remark_identifier` in array elements maps to `profile_remark_reason_id` via `seafarer_profile_remarks` → `profile_remark_reasons` mappings
- `created_by_id` (varchar) cast to uuid when valid UUID format; otherwise nil UUID
- Uses standardized SMAC `audit_info` structure via `migration.build_audit_info()`
- Requires `seafarers` table to be migrated first

## Special Considerations

- One SAC row can produce multiple SMAC rows when `profile_remark` contains multiple array elements
- Extract `remark_text` from unnested `profile_remark` array element `remark` field
- Script performs `TRUNCATE TABLE shore.seafarer_remarks` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `profile_remark_type_mapping` | FK lookup | `name_lower`, `target_id` | - | `smac_master_migration` |
| `profile_remark_reason_mappings` | Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id | `x.source_id`, `x.target_id` | `?.?.seafarer_profile_remarks` → `?.?.profile_remark_reasons` | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `profile_remark_type_mapping`

- **Output columns**: name_lower, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    id AS target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.profile_remark_types'
) AS t(id uuid, name text);
```

### `profile_remark_reason_mappings`

- **Purpose**: Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id
- **Output columns**: x.source_id, x.target_id
- **migration.table_mappings**: source_table=seafarer_profile_remarks, target_table=profile_remark_reasons
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings AS
SELECT x.source_id, x.target_id
FROM dblink(
    'smac_master_migration',
    $q$
    SELECT DISTINCT ON (norm.source_id)
        norm.source_id,
        norm.target_id
    FROM (
        SELECT
            CASE
                WHEN trim(coalesce(tm.source_id, '')) ~ '^[0-9]+$'
                THEN trim(tm.source_id)::bigint::text
                ELSE trim(tm.source_id)
            END AS source_id,
            tm.target_id
        FROM migration.table_mappings tm
        WHERE tm.target_table = 'profile_remark_reasons'
          AND tm.source_table = 'seafarer_profile_remarks'
          AND trim(coalesce(tm.source_id, '')) <> ''
    ) AS norm
    ORDER BY norm.source_id, norm.target_id
    $q$
) AS x(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only (no `uuid` column) |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; default `00000000-0000-0000-0000-000000000000` if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarers'` |
| 3 | `profile_remark` (JSONB) → `remark_type` | jsonb | `profile_remark_type_id` | uuid | Join `profile_remark_type_mapping` on LOWER(name); map `Inactive` → `deactivation`, `Active` → `activation` | Lookup: `crewing.profile_remark_types` via dblink (`smac_master_migration`); extracted from unnested array element |
| 4 | `profile_remark` (JSONB) → `remark_identifier` | jsonb | `profile_remark_reason_id` | uuid | Normalize numeric `remark_identifier` to `bigint::text`; join `profile_remark_reason_mappings` | Lookup: `migration.table_mappings` (`seafarer_profile_remarks` → `profile_remark_reasons`); nullable if no match |
| 5 | `profile_remark` (JSONB) → `remark` | jsonb | `remark_text` | text | `COALESCE(remark_json->>'remark', '')` from unnested array element | NOT NULL in SMAC; empty string used when `remark` field is missing |
| 6 | — | — | `severity` | text | `NULL` | No equivalent in SAC; not populated |
| 7 | — | — | `visibility` | character varying(50) | Hardcoded `'internal'` | SMAC default; not in SAC source |
| 8 | — | — | `related_entity` | text | `NULL` | No equivalent in SAC; not populated |
| 9 | — | — | `related_entity_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 10 | `created_by_id` | character varying | `created_by_id` | uuid | Cast to UUID when valid UUID format; else nil UUID | SAC stores as varchar; SMAC requires uuid NOT NULL |
| 11 | — | — | `status` | character varying(50) | Hardcoded `'Active'` | SAC has no `deleted_at` or `status` column; all migrated records set to Active |
| 12 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 13 | `created_at` | timestamp(6) without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at`, `created_at` | timestamp(6) without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 16 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at`; all records migrated |
| 17 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs and names combined into `notes` | Standardized SMAC audit structure; `legacy_id` not included (handled by `id_mappings`) |

**SMAC columns not migrated:** `date_of_action` — no source equivalent in SAC `seafarer_remarks`.

**SAC columns not migrated:** `absconded_Id` — not referenced in migration script; `updated_by_id`, `updated_by_name` (used only in `audit_info` notes, not as separate SMAC columns).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Profile Remark Type ID Mapping
**Output columns**: `name_lower, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    id AS target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.profile_remark_types'
) AS t(id uuid, name text);
```

### 3. Profile Remark Reason Mappings ID Mapping
**Purpose**: Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id
**Output columns**: `x.source_id, x.target_id`
**migration.table_mappings**: `seafarer_profile_remarks` → `profile_remark_reasons`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings AS
SELECT x.source_id, x.target_id
FROM dblink(
    'smac_master_migration',
    $q$
    SELECT DISTINCT ON (norm.source_id)
        norm.source_id,
        norm.target_id
    FROM (
        SELECT
            CASE
                WHEN trim(coalesce(tm.source_id, '')) ~ '^[0-9]+$'
                THEN trim(tm.source_id)::bigint::text
                ELSE trim(tm.source_id)
            END AS source_id,
            tm.target_id
        FROM migration.table_mappings tm
        WHERE tm.target_table = 'profile_remark_reasons'
          AND tm.source_table = 'seafarer_profile_remarks'
          AND trim(coalesce(tm.source_id, '')) <> ''
    ) AS norm
    ORDER BY norm.source_id, norm.target_id
    $q$
) AS x(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_remarks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_remarks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
