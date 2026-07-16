# Table Mapping: seafarer_checklists → seafarer_departure_checklist_items

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_checklists
- **New Database**: smac_master_migration
- **New Schema**: shore
- **New Table**: seafarer_departure_checklist_items
- **Source Script**: `04-migration-scripts/crewing/seafarer_departure_checklist_items_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_checklists`
- **New Path**: `smac_master_migration.shore.seafarer_departure_checklist_items`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departure Checklist Items (`seafarer_departures,seafarer_checklists` → `seafarer_departure_checklist_items`)

## Migration Notes

- Source: `synergy_manning.public.seafarer_checklists` joined to `seafarer_departures`
- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL`
- `seafarer_departure_id` → uuid via `seafarer_departure_id_mapping`; `departure_checklist_id` → `checklist_item_id` via master `departure_checklist` mappings
- `availability` remapped: Legacy 0=Yes→2, 1=No→1, 2=N/A→0 (`check_point`)
- `deviation_reviewers` JSONB array → uuid[] via email lookup on `user_profiles` (`smac_idp_dev`)
- `workflow_status_id` defaults to APPROVED; `deviation_flag` hardcoded `false`
- Requires `seafarer_departures` and `departure_checklist` master migrated first

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE shore.seafarer_departure_checklist_items` before insert (full table reload).
- Orchestration dependencies: `seafarer_departures`, `departure_checklist`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_departure_id_mapping` | Check if any mappings already exist for the given source and | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `checklist_item_id_mapping` | FK lookup | `legacy_departure_checklist_id`, `checklist_item_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |

### `seafarer_departure_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_departures

```sql
CREATE TEMP TABLE seafarer_departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `checklist_item_id_mapping`

- **Output columns**: legacy_departure_checklist_id, checklist_item_id
- **migration.table_mappings**: target_db=, target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE checklist_item_id_mapping AS
SELECT
    source_id::bigint AS legacy_departure_checklist_id,
    target_id AS checklist_item_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''departure_checklist'' /* AND target_db = ''smac_master_migration'' */ AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `seafarer_departure_id` | bigint | `seafarer_departure_id` | uuid | Map via `seafarer_departure_id_mapping`; nil UUID fallback | Lookup: `seafarer_departures` |
| 3 | `departure_checklist_id` | bigint | `checklist_item_id` | uuid | Map via `checklist_item_id_mapping`; nil UUID fallback | Lookup: `departure_checklist` master |
| 4 | `is_completed` | boolean | `is_completed` | boolean | `COALESCE(is_completed, false)` | NOT NULL default false |
| 5 | `updated_at` | timestamp | `completed_at` | timestamp | `updated_at` when `is_completed = true` | Completion timestamp |
| 6 | `updated_by_id` | text | `completed_by_id` | uuid | Cast to UUID when completed and valid format | From updater when item completed |
| 7 | `availability` | integer | `check_point` | integer | Legacy 0→2 (Yes), 1→1 (No), 2→0 (N/A) | Value remapping |
| 8 | `deviation_note` | text | `deviation_note` | text | Direct copy | Optional |
| 9 | `deviation_reviewers` | jsonb | `deviation_reviewers` | uuid[] | Extract `reviewed_by_email`; map via `user_email_id_mapping` | Lookup: `user_profiles` (`smac_idp_dev`) |
| 10 | `deviation_status` | integer | `deviation_status` | integer | `COALESCE(deviation_status, 0)` | NOT NULL default 0 |
| 11 | — | — | `deviation_flag` | boolean | Hardcoded `false` | Not derived from note in script |
| 12 | — | — | `workflow_status_id` | uuid | Default APPROVED from `workflow_status_id_mapping`; nil UUID fallback | Lookup: `workflow_status` code=APPROVED |
| 13 | — | — | `is_verified` | boolean | Hardcoded `false` | Not in SAC |
| 14 | — | — | `verified_at` | timestamp | `NULL` | No SAC equivalent |
| 15 | — | — | `verified_by_id` | uuid | `NULL` | No SAC equivalent |
| 16 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 19 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 21 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 22 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text, varchar | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | Standardized SMAC audit structure |

**SMAC columns not migrated:** `deviation_flag`, verification fields, `archived_at` — defaults/NULL (no SAC source).

**SAC columns not migrated:** None — all `seafarer_checklists` columns referenced in migration script are mapped.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `departure_checklist`
- `seafarer_departures`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Departure ID Mapping
**Purpose**: Check if any mappings already exist for the given source and
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_departures'`

```sql
CREATE TEMP TABLE seafarer_departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Checklist Item ID Mapping
**Output columns**: `legacy_departure_checklist_id, checklist_item_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE checklist_item_id_mapping AS
SELECT
    source_id::bigint AS legacy_departure_checklist_id,
    target_id AS checklist_item_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''departure_checklist'' /* AND target_db = ''smac_master_migration'' */ AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 3. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_departure_checklist_items_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departure_checklist_items_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departure_checklist_items_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
