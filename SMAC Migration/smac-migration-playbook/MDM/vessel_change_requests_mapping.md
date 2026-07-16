# Table Mapping: change_request_section → vessel_change_requests

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: change_request_section
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_change_requests
- **Source Script**: `04-migration-scripts/master/vessel_change_requests_migration.sql`

- **Legacy Path**: `synergy_vessel.public.change_request_section`
- **New Path**: `smac_master_migration.vessel.vessel_change_requests`

## Business Key

- **Composite Key**: (`vessel_id`, `current_revision_id`, `initiated_by`)
- **Source (orchestration)**: Vessel Change Requests (`vessel_details_cr` → `vessel_change_requests`)

## Migration Notes

- Preserve legacy identifier (UUID) as new id if available, otherwise generate new UUID
- Record legacy id → new uuid in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_details_cr to vessel_change_requests. Preserves identifier UUID as id when available. Maps vessel_id (bigint) to vessel_id (uuid) via migration.table_mappings. Maps vessel_id_new (bigint) to current_revision_id and proposed_revision_id (uuid) via migration.table_mappings. Maps approval_status (text) to cr_status (integer): Draft=0, PendingApproval=1, Approved=2, Rejected=3. Conditionally maps approval_status_changed_by/at to approved_by/at, rejected_by/at, or cancelled_by/at based on approval_status. Stores change_type, change_requested_sections, and other metadata in fields jsonb. Maps status (varchar) to status (integer) with deleted_at precedence. Requires vessels and vessel_revisions tables to be migrated first.

## Special Considerations

- Includes all rows (including deleted rows with deleted_at IS NOT NULL per Rule 2.6)
- Use DISTINCT ON (source_id) to prevent duplicate mappings when multiple staging rows match the same target row
- Script performs `TRUNCATE TABLE vessel.vessel_change_requests` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_identifier | - | id | - | COALESCE(s.legacy_identifier, gen_random_uuid()) AS id | COALESCE(s.legacy_identifier, gen_random_uuid()) |
| 2 | section_code, section_name | - | code | - | COALESCE( NULLIF(TRIM(s.section_code), ''), LEFT(UPPER(REPLACE(LEFT(TRIM(s.section_name), 15), ' ', '_')), 50) ) AS code | COALESCE( NULLIF(TRIM(s.section_code), ''), LEFT(UPPER(REPLACE(LEFT(TRIM(s.section_name), 15), ' ', '_')), 50) ) |
| 3 | section_name | - | name | - | LEFT(COALESCE(s.section_name, 'UNKNOWN'), 255) AS name | LEFT(COALESCE(s.section_name, 'UNKNOWN'), 255) |
| 4 | description | - | description | - | LEFT(COALESCE(s.description, ''), 1000) AS description | LEFT(COALESCE(s.description, ''), 1000) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 8 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 9 | legacy_status | - | status | - | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'DRAFT' THEN 1 WHEN UPPER(TRIM(COALESCE(s.legacy_status,... | CASE WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'ACTIVE' THEN 0 WHEN UPPER(TRIM(COALESCE(s.legacy_status, ''))) = 'DRAFT' THEN 1 WHEN UPPER(TRIM(COALESCE(s.legacy_status,... |
| 10 | legacy_created_at | - | created_at | - | COALESCE(s.legacy_created_at, NOW()) AS created_at | COALESCE(s.legacy_created_at, NOW()) |
| 11 | legacy_updated_at, legacy_created_at | - | updated_at | - | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) AS updated_at | COALESCE(s.legacy_updated_at, s.legacy_created_at, NOW()) |
| 12 | legacy_deleted_at | - | deleted_at | - | s.legacy_deleted_at AS deleted_at | s.legacy_deleted_at |
| 13 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 14 | legacy_created_by_id, legacy_updated_by_id, legacy_id, legacy_identifier | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN s.legacy_created_by_id IS NOT NULL AND s.legacy_created_by_id::text <> '' THEN s.legacy_created_by_id::text ELSE NULL END, 'deleted_b... | jsonb_build_object( 'created_by', CASE WHEN s.legacy_created_by_id IS NOT NULL AND s.legacy_created_by_id::text <> '' THEN s.legacy_created_by_id::text ELSE NULL END, 'deleted_b... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_change_requests_migration.sql`

## Validation

- Run `05-validation/master/vessel_change_requests_validation.sql` if available
- Run `06-rollback/master/vessel_change_requests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
