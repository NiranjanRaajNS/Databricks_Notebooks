# Table Mapping: seafarer_competency_tasks → seafarer_competency_tasks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_tasks
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_tasks
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_tasks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_tasks`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_tasks`

## Business Key

- **Composite Key**: (`task_id`, `seafarer_id`, `vessel_id`)
- **Source (orchestration)**: Seafarer Competency Tasks (`seafarer_competency_tasks` → `seafarer_competency_tasks`)

## Migration Notes

- SAC `id` (uuid) preserved as target `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_uuid` copied directly to `seafarer_id`; rows with NULL `seafarer_uuid` excluded
- `vessel_id` (bigint, references `vessel_details.id`) → SMAC `vessel_id` via `vessels_id_mapping`; unmapped vessel rows excluded when `vessel_id` is non-zero
- `competency_type` (text) → `competency_type_id` via name match on `crewing.competency_types`
- `rank_id` mapped via `ranks` table_mappings when available; else source UUID kept
- Column renames: `approved_on` → `approved_at`, `rejected_on` → `rejected_at`, `expiry_date` → `expiry_at`
- `comments`, `attachment_ids` (jsonb) cast to text; `workflow_status_id` defaults from `smac_master_migration`
- Requires `seafarers`, `vessels`, `ranks`, `vessel_categories` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_tasks` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `ranks`, `vessel_categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `vessel_id_target` | `migration.table_mappings` (see SQL) | `synergy_seafarer` |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `vessels_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, vessel_id_target
- **migration.table_mappings**: target_table=
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.seafarer_competency_tasks
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS sct(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = sct.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND target_db = current_database()'
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vd.vessel_id::text;
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves legacy UUID |
| 2 | `task_id` | uuid | `task_id` | uuid | Direct copy | Master competency task reference |
| 3 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Direct copy (`seafarer_uuid` → `seafarer_id`) | FK to `seafarers.id` (preserved UUID) |
| 4 | `vessel_category_id` | uuid | `vessel_category_id` | uuid | Direct copy | FK to vessel category |
| 5 | `competency_type` | text | `competency_type_id` | uuid | Join `competency_type_id_mapping` on `TRIM(competency_type)` | Lookup: `crewing.competency_types` (`smac_master_migration`); nullable |
| 6 | `vessel_id` | bigint | `vessel_id` | uuid | `COALESCE(vessels_id_mapping.vessel_id_target, nil UUID)` | `vessel_details.id` → `vessels` via mappings; nil UUID fallback |
| 7 | `rank_id` | uuid | `rank_id` | uuid | `COALESCE(rank_id_mapping.new_id, rank_id)` | Lookup: `ranks` mappings when available |
| 8 | `approved_by` | uuid | `approved_by` | uuid | Direct copy | |
| 9 | `approved_on` | timestamp(6) | `approved_at` | timestamp | Direct copy | Column rename |
| 10 | `rejected_by` | uuid | `rejected_by` | uuid | Direct copy | |
| 11 | `rejected_on` | timestamp(6) | `rejected_at` | timestamp | Direct copy | Column rename |
| 12 | `comments` | jsonb | `comments` | text | jsonb → text (`::text`) | Type change |
| 13 | `rejection_reason_id` | uuid | `rejection_reason_id` | uuid | Direct copy | |
| 14 | `expiry_date` | timestamp(6) | `expiry_at` | timestamp | Direct copy | Column rename |
| 15 | `attachment_ids` | jsonb | `attachment_ids` | text | jsonb → text (`::text`) | Type change |
| 16 | — | — | `workflow_status_id` | uuid | `COALESCE(default_workflow_status.id, nil UUID)` | Lookup: first `workflow_status` from `smac_master_migration` |
| 17 | — | — | `is_verified` | boolean | Hardcoded `FALSE` | Not in SAC |
| 18 | — | — | `verified_at` | timestamp | `NULL` | No SAC equivalent |
| 19 | — | — | `verified_by_id` | uuid | `NULL` | No SAC equivalent |
| 20 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 21 | `status` | text | `status` | text | `TRIM(COALESCE(status, ''))` | NOT NULL |
| 22 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 23 | `created_at` | timestamp(6) | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 24 | `updated_at` | timestamp(6) | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 25 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 26 | `deleted_at` | timestamp(6) | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 27 | `created_by_id`, `deleted_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` — legacy seafarer/vessel/competency_type in `notes` | Standardized SMAC audit structure |
| 28 | — | — | `name` | text | `NULL` | New optional SMAC field |

**SMAC columns not migrated:** `name`, verification fields — set to defaults/NULL.

**SAC columns not migrated:** `deleted_by_id` — used only in `audit_info` via `build_audit_info`, not as separate SMAC column beyond audit structure.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ranks`
- `seafarers`
- `vessel_categories`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, vessel_id_target`
**migration.table_mappings**: see SQL below
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.seafarer_competency_tasks
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS sct(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = sct.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND target_db = current_database()'
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vd.vessel_id::text;
```

### 2. Rank ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_competency_tasks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_tasks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_tasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
