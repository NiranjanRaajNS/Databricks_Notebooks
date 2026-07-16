# Table Mapping: seafarer_departures → seafarer_departures

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_departures
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_departures
- **Source Script**: `04-migration-scripts/crewing/seafarer_departures_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_departures`
- **New Path**: `smac_crewing_migration.shore.seafarer_departures`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departures (`seafarer_departures` → `seafarer_departures`)

## Migration Notes

- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL` (idempotent UUID)
- `seafarer_id` mapped via `seafarer_id_mapping` (INNER JOIN — required)
- `relief_id` → `assignment_id` via `relief_summary.planned_relief_id` join; nil UUID fallback
- `shore_user_signed_at` → `actual_departure_date` (date) and `verified_at`; drives `is_verified` when status = SIGNED
- `shore_user_id` → `verified_by_id` via `user_profiles` (`smac_idp_dev`) or direct UUID cast
- `status` (text) → `progress_status`; `workflow_status_id` = SIGNED for signed/checklist_verified, else INFORCE
- `deleted_at` drives integer `status` (0=Active, 3=Deleted per constants.sql)
- Requires `seafarers`, `relief_summary`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_departures` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `workflow_status`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `workflow_status_signed_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `workflow_status_inforce_mapping` | Query public.user_profiles from sma | `workflow_status_id` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `workflow_status_signed_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_signed_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''SIGNED'' LIMIT 1'
) AS t(id uuid);
```

### `workflow_status_inforce_mapping`

- **Purpose**: Query public.user_profiles from sma
- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_inforce_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''INFORCE'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping` (INNER JOIN) | Lookup: `migration.table_mappings` (`seafarers`) |
| 3 | `relief_id` | bigint | `assignment_id` | uuid | Join `relief_summary` on `planned_relief_id`; nil UUID fallback | From `public.relief_summary` |
| 4 | — | — | `planned_departure_date` | date | `NULL` | No SAC equivalent |
| 5 | `shore_user_signed_at` | timestamp | `actual_departure_date` | date | `shore_user_signed_at::date` when not NULL | Sign-off date proxy |
| 6 | — | — | `departure_report` | uuid[] | `NULL` | File UUIDs not resolved in this script |
| 7 | `status` | text | `progress_status` | text | `TRIM(status)` | SAC workflow status text preserved |
| 8 | `status` | text | `workflow_status_id` | uuid | SIGNED code when status in (signed, checklist_verified); else INFORCE | Lookup: `workflow_status` (`smac_master_migration`) |
| 9 | `shore_user_signed_at`, `status` | timestamp, text | `is_verified` | boolean | `true` when signed_at not NULL and status = SIGNED | Verification flag |
| 10 | `shore_user_signed_at` | timestamp | `verified_at` | timestamp | Direct copy | Verification timestamp |
| 11 | `shore_user_id` | varchar | `verified_by_id` | uuid | Map via `user_profile_id_mapping`; fallback valid UUID cast; nil UUID default | Lookup: `user_profiles` (`smac_idp_dev`) |
| 12 | — | — | `verification_notes` | text | `NULL` | No SAC equivalent |
| 13 | `deleted_at` | timestamp | `status` | integer | `3` (Deleted) when `deleted_at IS NOT NULL`, else `0` (Active) | Case 1: deleted_at drives status |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 16 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 17 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 18 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 19 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | Standardized SMAC audit structure |

**SMAC columns not migrated:** `planned_departure_date`, `departure_report`, `verification_notes`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** `seafarer_signed_at`, `file_name`, `file_content_type`, `file_url`, `file_size` — migrated separately via `seafarer_departure_attachments` script.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_vessel_assignments`
- `seafarers`
- `workflow_status`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Workflow Status Signed ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_signed_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''SIGNED'' LIMIT 1'
) AS t(id uuid);
```

### 3. Workflow Status Inforce ID Mapping
**Purpose**: Query public.user_profiles from sma
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_inforce_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''INFORCE'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_departures_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departures_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departures_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
