# Table Mapping: seafarer_restrictions → seafarer_restrictions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_restrictions
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_restrictions
- **Source Script**: `04-migration-scripts/crewing/seafarer_restrictions_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_restrictions`
- **New Path**: `smac_crewing_migration.public.seafarer_restrictions`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Restrictions (`seafarer_restrictions` → `seafarer_restrictions`)

## Migration Notes

- SAC `vessel_id` is `bigint[]` — unnested to one SMAC row per vessel element
- SAC `id` (uuid) preserved as SMAC `"Id"` via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_uuid` mapped to `"SeafarerId"` via direct match on `public.seafarers.id`
- `vessel_id` array elements mapped to `"VesselId"` via `vessel_uuid_mapping`; negative IDs use `ABS()` (e.g. -99 → 99)
- `restricted_flags` (jsonb) cast to `"RestrictedFlags"` text
- Rows with NULL `vessel_id` elements excluded after unnest
- Uses `migration.build_audit_info()` for standardized SMAC `audit_info`
- Requires `seafarers` and `vessels` migrated first

## Special Considerations

- Converts restricted_flags (jsonb) → RestrictedFlags (text)
- Script performs `TRUNCATE TABLE public.seafarer_restrictions` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_uuid_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `seafarer_uuid_mapping` | FK lookup | `legacy_uuid`, `target_id` | - | - |

### `vessel_uuid_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND source_id ~ ''^-?[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `seafarer_uuid_mapping`

- **Output columns**: legacy_uuid, target_id

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT id AS legacy_uuid, id AS target_id
FROM public.seafarers;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `"Id"` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID; idempotent via `id_mappings` |
| 2 | `seafarer_uuid` | uuid | `"SeafarerId"` | uuid | Map via `seafarer_uuid_mapping`; default nil UUID if unmapped | Direct UUID match on `public.seafarers.id` |
| 3 | `vessel_id` (array element) | bigint | `"VesselId"` | uuid | Map via `vessel_uuid_mapping` on `ABS(vessel_id)`; default nil UUID if unmapped | One row per unnested array element |
| 4 | `reason` | text | `"Reason"` | text | `TRIM(reason)` | Direct copy with whitespace trimmed |
| 5 | `restricted_flags` | jsonb | `"RestrictedFlags"` | text | `restricted_flags::text` when NOT NULL; else NULL | JSONB serialized to text |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 8 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 9 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved; all records migrated |
| 11 | `created_by_id`, `updated_by_id`, `deleted_by_id` | uuid | `audit_info` | jsonb | `migration.build_audit_info()` | Standardized SMAC audit structure; no `legacy_id` (UUID preserved as `Id`) |

**SMAC columns not migrated:** None — all target columns populated from source or defaults.

**SAC columns not migrated:** Parent `vessel_id` array — only unnested elements migrated; rows where all vessel elements are NULL excluded.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Uuid ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND source_id ~ ''^-?[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 2. Seafarer Uuid ID Mapping
**Output columns**: `legacy_uuid, target_id`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT id AS legacy_uuid, id AS target_id
FROM public.seafarers;
```

Full migration context: `04-migration-scripts/crewing/seafarer_restrictions_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_restrictions_validation.sql` if available
- Run `06-rollback/crewing/seafarer_restrictions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
