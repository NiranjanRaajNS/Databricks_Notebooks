# Table Mapping: vessel_details_vct → vct_activity_logs

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details_vct
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vct_activity_logs
- **Source Script**: `04-migration-scripts/master/vessel_details_vct_activity_logs_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details_vct`
- **New Path**: `smac_master_migration.vessel.vct_activity_logs`

## Business Key

- **Composite Key**: (`vct_requests_id`, `user_id`, `created_at`)
- **Source (orchestration)**: VCT Activity Logs (`vessel_details_vct` → `vct_activity_logs`)

## Migration Notes

- Source: `synergy_vessel.public.vessel_details_vct` approval fields → `vessel.vct_activity_logs`
- Four separate INSERT blocks: OT approval, OT rejection, final approval, final rejection (one row per action when actor field IS NOT NULL)
- `id` via `gen_random_uuid()` — new UUID per activity log row (not idempotent)
- `vct_requests_id` and `\"VctRequestId\"` both set from `vct_requests_id_mapping` (match on `id` bigint or `identifier` UUID text)
- Requires `vct_requests` migrated first; no `migration.table_mappings` entries stored for activity logs
- `vct_status` hardcoded per branch: OT approval→1, final approval→2, OT/final rejection→3
- Migrate ALL source rows including deleted (per Rule 2.6)
## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Script performs `TRUNCATE TABLE vessel.vct_activity_logs` before insert (full table reload).
- Orchestration dependencies: `vct_requests`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vct_requests_id_mapping` | FK lookup | `legacy_source_id_text`, `legacy_id`, `vct_requests_id` | `migration.table_mappings` (see SQL) | - |

### `vct_requests_id_mapping`

- **Output columns**: legacy_source_id_text, legacy_id, vct_requests_id
- **migration.table_mappings**: target_table=vct_requests

```sql
CREATE TEMP TABLE vct_requests_id_mapping AS
SELECT DISTINCT
    tm.source_id AS legacy_source_id_text,
    CASE
        WHEN tm.source_id ~ '^\d+$'
        THEN tm.source_id::bigint
        ELSE NULL
    END AS legacy_id,
    tm.target_id AS vct_requests_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vct_requests'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `—` | — | `id` | uuid | `gen_random_uuid()` | New UUID per activity row; not stored in `table_mappings` |
| 2 | `id, identifier` | bigint, uuid | `vct_requests_id` | uuid | Join `vct_requests_id_mapping` on `legacy_id = id` OR `legacy_source_id_text = identifier::text` | FK lookup from `vct_requests` migration |
| 3 | `id, identifier` | bigint, uuid | `VctRequestId` | uuid | Same value as `vct_requests_id` | Duplicate FK column (quoted identifier in SQL) |
| 4 | `ot_approved_by / ot_rejected_by / approved_by / rejected_by` | uuid | `user_id` | uuid | Per INSERT branch — actor UUID from respective `*_by` column | Four conditional INSERT blocks |
| 5 | `—` | — | `vct_status` | integer | OT approval→1 (PendingApproval); final approval→2 (Approved); OT rejection→3; final rejection→3 | Hardcoded per INSERT branch |
| 6 | `ot_approved_by, ot_approved_by_name, ot_approval_remarks / ot_rejected_by, ot_rejected_by_name, ot_reason_for_rejection / approved_by, approved_by_name, approval_remarks / rejected_by, rejected_by_name, reason_for_rejection` | uuid, varchar, text | `field_json` | jsonb | `jsonb_build_object` with `action` (`ot_approval`, `ot_rejection`, `final_approval`, `final_rejection`) and actor metadata | Action-specific JSON per branch |
| 7 | `ot_approval_remarks / ot_reason_for_rejection / approval_remarks / reason_for_rejection` | text | `remarks` | text | `TRIM(COALESCE(..., ''))` on respective remarks field per branch | Action-specific remarks |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `—` | — | `parent_id` | uuid | `NULL` | Not populated |
| 10 | `—` | — | `level` | numeric | `NULL` | Not populated |
| 11 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 12 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Script uses literal 0 |
| 13 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Script uses literal 0 |
| 14 | `deleted_at` | timestamp | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Simplified status mapping |
| 15 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 16 | `updated_at, created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Fallback chain |
| 17 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 18 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not populated |
| 19 | `audit_info, id` | jsonb, bigint | `audit_info` | jsonb | `migration.build_audit_info()` — `created_by` from legacy `audit_info`; `legacy_id` + action name in `notes` | No `legacy_id` in standard audit fields |
| 20 | `—` | — | `tags` | text[] | `NULL` | Not populated |

**SAC columns not migrated:** All non-approval `vessel_details_vct` columns — migrated in `vessel_details_vct` script.

**INSERT branch filters:** `ot_approved_by IS NOT NULL` | `ot_rejected_by IS NOT NULL` | `approved_by IS NOT NULL` | `rejected_by IS NOT NULL`.

**Note:** Up to 4 activity log rows per source VCT record (one per approval action).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`
- `vct_requests`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vct Requests ID Mapping
**Output columns**: `legacy_source_id_text, legacy_id, vct_requests_id`
**migration.table_mappings**: `target_table='vct_requests'`

```sql
CREATE TEMP TABLE vct_requests_id_mapping AS
SELECT DISTINCT
    tm.source_id AS legacy_source_id_text,
    CASE
        WHEN tm.source_id ~ '^\d+$'
        THEN tm.source_id::bigint
        ELSE NULL
    END AS legacy_id,
    tm.target_id AS vct_requests_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vct_requests'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_details_vct_activity_logs_migration.sql`

## Validation

- Run `05-validation/master/vessel_details_vct_activity_logs_validation.sql` if available
- Run `06-rollback/master/vessel_details_vct_activity_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
