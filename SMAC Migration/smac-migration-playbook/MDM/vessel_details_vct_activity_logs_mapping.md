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

- Creates activity log entries from approval fields in vessel_details_vct
- One entry per approval action (OT approval, OT rejection, final approval, final rejection)
- References vct_requests via vct_requests_id
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- source_id in migration.table_mappings for vct_requests can be either:
- identifier UUID (as text) when identifier exists: "a0c17d71-d950-4b1a-b923-ae8b4fd9283d"
- id bigint (as text) when identifier is NULL: "12345"
- Creates activity log entries from approval fields in vessel_details_vct. Creates one entry per approval action: OT approval, OT rejection, final approval, final rejection. References vct_requests via vct_requests_id. Stores approval details in field_json. Maps vct_status based on approval state. Requires vct_requests table to be migrated first.

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
| 1 | - | - | id | - | gen_random_uuid() AS id | gen_random_uuid() |
| 2 | derived | - | vct_requests_id | - | vcr_map.vct_requests_id AS vct_requests_id | vcr_map.vct_requests_id |
| 3 | derived | - | "VctRequestId" | - | vcr_map.vct_requests_id AS "VctRequestId" | vcr_map.vct_requests_id AS "VctRequestId" |
| 4 | legacy_ot_approved_by | - | user_id | - | s.legacy_ot_approved_by AS user_id | s.legacy_ot_approved_by |
| 5 | derived | - | vct_status | - | 1 AS vct_status | 1 |
| 6 | legacy_ot_approved_by, legacy_ot_approved_by_name, legacy_ot_approval_remarks | - | field_json | - | jsonb_build_object( 'action', 'ot_approval', 'approved_by', s.legacy_ot_approved_by, 'approved_by_name', s.legacy_ot_approved_by_name, 'approval_remarks', s.legacy_ot_approval_r... | jsonb_build_object( 'action', 'ot_approval', 'approved_by', s.legacy_ot_approved_by, 'approved_by_name', s.legacy_ot_approved_by_name, 'approval_remarks', s.legacy_ot_approval_r... |
| 7 | legacy_ot_approval_remarks | - | remarks | - | TRIM(COALESCE(s.legacy_ot_approval_remarks, '')) AS remarks | TRIM(COALESCE(s.legacy_ot_approval_remarks, '')) |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 10 | derived | - | level | - | NULL AS level | NULL |
| 11 | derived | - | version | - | 1 AS version | 1 |
| 12 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 13 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 14 | legacy_deleted_at | - | status | - | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN s.legacy_deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 15 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 16 | legacy_updated_at, legacy_created_at | - | updated_at | - | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) |
| 17 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 18 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 19 | legacy_audit_info, legacy_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN s.legacy_audit_info IS NOT NULL AND s.legacy_audit_info->>'created_by' IS NOT NULL AND s.legacy_audit_info->>'created_by' <> '' THEN s.lega... |
| 20 | derived | - | tags | - | NULL AS tags | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `migrations`

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
