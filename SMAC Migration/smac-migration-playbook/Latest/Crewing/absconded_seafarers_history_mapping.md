# Table Mapping: absconded_seafarers_history → absconded_seafarers_history

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: absconded_seafarers_history
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: absconded_seafarers_history
- **Source Script**: `04-migration-scripts/crewing/absconded_seafarers_history_migration.sql`

- **Legacy Path**: `synergy_manning.public.absconded_seafarers_history`
- **New Path**: `smac_crewing_migration.public.absconded_seafarers_history`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Absconded Seafarers History (`absconded_seafarers_history` → `absconded_seafarers_history`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `relief_id` mapped to `assignment_id` via `assignment_id_mapping` (`migration.table_mappings` where `target_table = 'seafarer_vessel_assignments'`)
- `signoff_reason_id` mapped to `sign_off_reason_id` via `signoff_reason_id_mapping` (dblink to `smac_master_migration`, `target_table = 'sign_off_reasons'`)
- `seafarer_uuid` copied directly to `seafarer_id` (both UUID)
- `status` derived from `deleted_at` + `status` text (Case 2 — `deleted_at` takes precedence); SMAC uses text status values
- Requires `seafarers`, `seafarer_vessel_assignments`, and `sign_off_reasons` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.absconded_seafarers_history` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `signoff_reasons`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `assignment_id_mapping` | FK lookup | `legacy_relief_id`, `assignment_id` | `migration.table_mappings` (see SQL) | - |
| `signoff_reason_id_mapping` | FK lookup | `legacy_reason_id`, `sign_off_reason_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `assignment_id_mapping`

- **Output columns**: legacy_relief_id, assignment_id
- **migration.table_mappings**: target_table=seafarer_vessel_assignments

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `signoff_reason_id_mapping`

- **Output columns**: legacy_reason_id, sign_off_reason_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE signoff_reason_id_mapping AS
SELECT
    source_id::bigint AS legacy_reason_id,
    target_id AS sign_off_reason_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'' AND target_db = current_database() AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID as SMAC `id`; idempotent via `id_mappings` |
| 2 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Direct copy | SAC seafarer UUID used as SMAC `seafarer_id`; NOT NULL |
| 3 | `relief_id` | bigint | `assignment_id` | uuid | Map via `assignment_id_mapping`; default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarer_vessel_assignments'` |
| 4 | `signoff_reason_id` | bigint | `sign_off_reason_id` | uuid | Map via `signoff_reason_id_mapping`; default nil UUID if unmapped | Lookup: dblink `smac_master_migration` → `sign_off_reasons` mappings |
| 5 | `investigation_remarks` | text | `investigation_remarks` | text | `TRIM(investigation_remarks)` | Direct copy with whitespace trimmed |
| 6 | `closure_date` | timestamp without time zone | `closure_date` | timestamp without time zone | Direct copy | Nullable |
| 7 | `is_seafarer_deactivation_required` | boolean | `is_seafarer_deactivation_required` | boolean | Direct copy | Nullable |
| 8 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | text | `deleted_at IS NOT NULL` → `Deleted`; else map `status` string/integer to Active/Draft/Inactive/Deleted text | Case 2 — `deleted_at` takes precedence; NOT NULL in SMAC |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | NOT NULL in SMAC |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 13 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | uuid, character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated/deleted by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (UUID preserved as `id`) |

**SMAC columns not migrated:** None — all target columns populated from SAC or defaults.

**SAC columns not migrated:** `deleted_by_name` — used only indirectly via audit context; `relief_id` and `signoff_reason_id` resolved via lookup tables (not stored as separate SMAC columns).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_vessel_assignments`
- `seafarers`
- `signoff_reasons`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Assignment ID Mapping
**Output columns**: `legacy_relief_id, assignment_id`
**migration.table_mappings**: `target_table='seafarer_vessel_assignments'`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Signoff Reason ID Mapping
**Output columns**: `legacy_reason_id, sign_off_reason_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE signoff_reason_id_mapping AS
SELECT
    source_id::bigint AS legacy_reason_id,
    target_id AS sign_off_reason_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'' AND target_db = current_database() AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/crewing/absconded_seafarers_history_migration.sql`

## Validation

- Run `05-validation/crewing/absconded_seafarers_history_validation.sql` if available
- Run `06-rollback/crewing/absconded_seafarers_history_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
