# Table Mapping: reimbursement_request_items → seafarer_reimbursements

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: reimbursement_request_items
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_reimbursements
- **Source Script**: `04-migration-scripts/crewing/seafarer_reimbursements_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.reimbursement_request_items`
- **New Path**: `smac_crewing_migration.shore.seafarer_reimbursements`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Reimbursements (`reimbursement_request_items` → `seafarer_reimbursements`)

## Migration Notes

- Uses standardized SMAC audit_info on insert (explicit jsonb_build_object: UUID user fields, workflow/reviewer keys;
- reimbursement_categories and reimbursement_types are in smac_master_migration, not smac_crewing_migration
- workflow_statuses table check is optional - will use fallback if not available
- Migrates reimbursement_request_items to seafarer_reimbursements table. Generates new UUIDs for id column (source id is bigint, target id is uuid). Maps seafarer_id from parent reimbursement_requests table via migration.table_mappings from smac_crewing_migration. Maps category_id (integer) to uuid via migration.table_mappings from smac_master_migration (reimbursement_categories). Maps reimbursement_type_id from parent reimbursement_requests.request_type via migration.table_mappings from smac_master_migration (reimbursement_types). Converts numeric fields with precision. Maps status text to status and payment_status fields. Sets defaults for new required fields: workflow_status_id (UUID), tenant_id, archived_at (NULL). Only migrates records where seafarer_id can be mapped.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_reimbursements` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `reimbursement_categories`, `reimbursement_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 10

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `reimbursement_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `reimbursement_sub_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `reimbursement_types_id_mapping` | Create empty temp table if connection doesn | `legacy_type_name`, `new_id` | - | `smac_master_migration` |
| `seafarers_id_mapping` | FK lookup | `crew_code`, `seafarer_id` | - | - |
| `shore_user_legacy_to_uuid` | Create empt | `legacy_user_key`, `smac_user_id` | `?.?.Users` → `?.public.users` | - |
| `seafarer_id_legacy_for_relief_summary` | Map source type names to target type names: | `legacy_seafarer_id`, `new_seafarer_id`, `crew_code` | - | `synergy_seafarer` |
| `vessel_imo_mapping` | FK lookup | `imo_number`, `vessel_id` | - | `smac_master_migration` |
| `workflow_status_lookup` | Map crewCode from reimbursement_requests to seafarer UUID via seafarers table | `workflow_status_id`, `workflow_status_name`, `workflow_status_code`, `workflow_status_value` | - | `smac_master_migration` |
| `pre_computed_assignment_id_mapping` | FK lookup | `reimbursement_item_id`, `frs.assignment_id`, `frs.relief_created_at`, `frs.contract_end_date` | - | - |
| `workflow_status_normalized_mapping` | FK lookup | `s.legacy_id`, `workflow_status_id` | - | - |

### `reimbursement_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_categories_id_mapping AS
SELECT
            source_id::integer AS legacy_id,
            target_id AS new_id
        FROM dblink('smac_master_migration',
            'SELECT source_id, target_id
             FROM migration.table_mappings
             WHERE target_table = ''reimbursement_categories''
               AND target_db = current_database()
               AND source_id ~ ''^[0-9]+$'''  -- Only fetch rows where source_id is numeric
        ) AS t(source_id VARCHAR(100), target_id UUID);
```

### `reimbursement_sub_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_sub_categories_id_mapping AS
SELECT
            source_id::integer AS legacy_id,
            target_id AS new_id
        FROM dblink('smac_master_migration',
            'SELECT source_id, target_id
             FROM migration.table_mappings
             WHERE target_table = ''reimbursement_sub_categories''
               AND target_db = current_database()'
        ) AS t(source_id VARCHAR(100), target_id UUID);
```

### `reimbursement_types_id_mapping`

- **Purpose**: Create empty temp table if connection doesn
- **Output columns**: legacy_type_name, new_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_types_id_mapping AS
SELECT

            CASE
                WHEN UPPER(TRIM(rt.name)) = 'PRE JOINING' THEN 'Before Joining'
                WHEN UPPER(TRIM(rt.name)) = 'ON BOARDING' THEN 'On Boarding'
                ELSE rt.name
            END AS legacy_type_name,
            rt.id AS new_id
        FROM dblink('smac_master_migration',
            $dblink_query$SELECT id, name FROM crewing.reimbursement_types WHERE name IS NOT NULL$dblink_query$
        ) AS rt(id uuid, name text)
        WHERE rt.name IS NOT NULL;
```

### `seafarers_id_mapping`

- **Output columns**: crew_code, seafarer_id

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    TRIM(s.crew_code) AS crew_code,
    s.id AS seafarer_id
FROM public.seafarers s
INNER JOIN reimbursement_request_crew_codes rrc ON
    TRIM(UPPER(s.crew_code)) = TRIM(UPPER(rrc.crew_code))
WHERE s.crew_code IS NOT NULL
  AND TRIM(s.crew_code) != '';
```

### `shore_user_legacy_to_uuid`

- **Purpose**: Create empt
- **Output columns**: legacy_user_key, smac_user_id
- **migration.table_mappings**: source_table=Users, target_schema=public, target_table=users

```sql
CREATE TEMP TABLE shore_user_legacy_to_uuid AS
SELECT DISTINCT ON (TRIM(m.source_id))
    TRIM(m.source_id) AS legacy_user_key,
    m.target_id AS smac_user_id
FROM migration.table_mappings m
WHERE m.target_table = 'users'
  AND m.target_schema = 'public'
  AND m.source_table = 'Users'
ORDER BY TRIM(m.source_id), m.migrated_at DESC NULLS LAST;
```

### `seafarer_id_legacy_for_relief_summary`

- **Purpose**: Map source type names to target type names:
- **Output columns**: legacy_seafarer_id, new_seafarer_id, crew_code
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_id_legacy_for_relief_summary AS
SELECT DISTINCT
            s.id AS legacy_seafarer_id,
            sim.seafarer_id AS new_seafarer_id,
            TRIM(UPPER(s.crew_code)) AS crew_code
        FROM dblink('synergy_seafarer',
            'SELECT id, crew_code FROM public.seafarers WHERE crew_code IS NOT NULL'
        ) AS s(id bigint, crew_code text)
        INNER JOIN seafarers_id_mapping sim ON TRIM(UPPER(sim.crew_code)) = TRIM(UPPER(s.crew_code));
```

### `vessel_imo_mapping`

- **Output columns**: imo_number, vessel_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT
            TRIM(v.imo_number)::text AS imo_number,
            v.id AS vessel_id
        FROM dblink('smac_master_migration',
            'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
        ) AS v(id uuid, imo_number text)
        WHERE v.imo_number IS NOT NULL AND TRIM(v.imo_number) != '';
```

### `workflow_status_lookup`

- **Purpose**: Map crewCode from reimbursement_requests to seafarer UUID via seafarers table
- **Output columns**: workflow_status_id, workflow_status_name, workflow_status_code, workflow_status_value
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
            ws.id AS workflow_status_id,
            ws.name AS workflow_status_name,
            ws.code AS workflow_status_code,
            ws.workflow_status::integer AS workflow_status_value
        FROM dblink('smac_master_migration',
            $dblink_query$SELECT id, name, code, workflow_status FROM public.workflow_status WHERE workflow_status IS NOT NULL$dblink_query$
        ) AS ws(id uuid, name text, code text, workflow_status integer);
```

### `pre_computed_assignment_id_mapping`

- **Output columns**: reimbursement_item_id, frs.assignment_id, frs.relief_created_at, frs.contract_end_date

```sql
CREATE TEMP TABLE pre_computed_assignment_id_mapping AS
SELECT DISTINCT ON (s.legacy_id)
        s.legacy_id AS reimbursement_item_id,
        frs.assignment_id,
        frs.relief_created_at,
        frs.contract_end_date
    FROM staging_reimbursement_request_items s

    INNER JOIN seafarer_id_legacy_for_relief_summary sil ON
        UPPER(sil.crew_code) = UPPER(TRIM(s.request_crew_code))
        AND s.request_crew_code IS NOT NULL
        AND TRIM(s.request_crew_code) != ''

    INNER JOIN pre_filtered_relief_summary frs ON
        frs.seafarer_id = sil.legacy_seafarer_id
        AND frs.vessel_imo_number = TRIM(s.request_vessel_imo_number)
        AND s.request_vessel_imo_number IS NOT NULL
        AND TRIM(s.request_vessel_imo_number) != ''

        AND s.created_at >= COALESCE(frs.relief_created_at, '1900-01-01'::timestamp)
        AND s.created_at <= COALESCE(frs.contract_end_date::timestamp, '9999-12-31'::timestamp)
    ORDER BY s.legacy_id, frs.relief_created_at DESC NULLS LAST;
```

### `workflow_status_normalized_mapping`

- **Output columns**: s.legacy_id, workflow_status_id

```sql
CREATE TEMP TABLE workflow_status_normalized_mapping AS
SELECT
        s.legacy_id,
        COALESCE(
            ws_lookup.workflow_status_id,
            (SELECT id FROM default_workflow_status LIMIT 1),
            '00000000-0000-0000-0000-000000000000'::uuid
        ) AS workflow_status_id
    FROM staging_reimbursement_request_items s
    LEFT JOIN workflow_status_lookup ws_lookup ON
        UPPER(TRIM(ws_lookup.workflow_status_code)) =
        CASE
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'APPROVED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'approved' THEN 'APPROVED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'REJECTED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'rejected' THEN 'REJECTED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'FORWARDED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'forwarded' THEN 'FORWARDED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'INPROGRESS' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'in_progress' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'inprogress' THEN 'INPROGRESS'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'REQUESTATTACHMENTS' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'request_attachments'...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | legacy_id | - | id | - | DISTINCT ON (s.legacy_id) gen_random_uuid() AS id | DISTINCT ON (s.legacy_id) gen_random_uuid() |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_map.seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(seafarer_map.seafarer_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | reimbursement_type_id | - | COALESCE(type_map.new_id, NULL) AS reimbursement_type_id | COALESCE(type_map.new_id, NULL) |
| 4 | derived | - | category_id | - | COALESCE(cat_map.new_id, NULL) AS category_id | COALESCE(cat_map.new_id, NULL) |
| 5 | derived | - | subcategory_id | - | COALESCE(sub_cat_map.new_id, NULL) AS subcategory_id | COALESCE(sub_cat_map.new_id, NULL) |
| 6 | claim_note, request_type_name | - | course_name | - | COALESCE( NULLIF(TRIM(COALESCE(s.claim_note, '')), ''), NULLIF(TRIM(COALESCE(s.request_type_name, '')), ''), 'Reimbursement' ) AS course_name | COALESCE( NULLIF(TRIM(COALESCE(s.claim_note, '')), ''), NULLIF(TRIM(COALESCE(s.request_type_name, '')), ''), 'Reimbursement' ) |
| 7 | claim_note | - | description | - | TRIM(COALESCE(s.claim_note, '')) AS description | TRIM(COALESCE(s.claim_note, '')) |
| 8 | claim_amount | - | amount | - | CAST(COALESCE(s.claim_amount, 0) AS numeric(12,2)) AS amount | CAST(COALESCE(s.claim_amount, 0) AS numeric(12,2)) |
| 9 | approved_amount | - | approved_amount | - | CAST(COALESCE(s.approved_amount, 0) AS numeric(12,2)) AS approved_amount | CAST(COALESCE(s.approved_amount, 0) AS numeric(12,2)) |
| 10 | converted_currency_code | - | base_currency | - | TRIM(COALESCE(s.converted_currency_code, 'USD')) AS base_currency | TRIM(COALESCE(s.converted_currency_code, 'USD')) |
| 11 | currency_code | - | claimed_currency | - | TRIM(COALESCE(s.currency_code, 'USD')) AS claimed_currency | TRIM(COALESCE(s.currency_code, 'USD')) |
| 12 | currency_rate_applied | - | exchange_rate | - | CAST(COALESCE(s.currency_rate_applied, 1) AS numeric(12,2)) AS exchange_rate | CAST(COALESCE(s.currency_rate_applied, 1) AS numeric(12,2)) |
| 13 | created_at | - | expense_date | - | COALESCE(s.created_at, NOW()) AS expense_date | COALESCE(s.created_at, NOW()) |
| 14 | derived | - | receipt_attachments | - | '{}'::uuid[] AS receipt_attachments | '{}'::uuid[] |
| 15 | created_by_id | - | claimed_by | - | CASE WHEN s.created_by_id IS NOT NULL AND s.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN s.created_by_id::uuid ELSE NULL END AS claimed_by | CASE WHEN s.created_by_id IS NOT NULL AND s.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN s.created_by_id::uuid ELSE NULL END |
| 16 | created_at | - | claimed_on | - | COALESCE(s.created_at, NOW()) AS claimed_on | COALESCE(s.created_at, NOW()) |
| 17 | status | - | payment_status | - | CASE WHEN UPPER(TRIM(COALESCE(s.status, ''))) LIKE '%PAID%' THEN 2 WHEN UPPER(TRIM(COALESCE(s.status, ''))) LIKE '%APPROVED%' THEN 1 ELSE 0 END::integer AS payment_status | CASE WHEN UPPER(TRIM(COALESCE(s.status, ''))) LIKE '%PAID%' THEN 2 WHEN UPPER(TRIM(COALESCE(s.status, ''))) LIKE '%APPROVED%' THEN 1 ELSE 0 END::integer |
| 18 | claim_note | - | remarks | - | TRIM(COALESCE(s.claim_note, '')) AS remarks | TRIM(COALESCE(s.claim_note, '')) |
| 19 | derived | - | assignment_id | - | assignment_map.assignment_id AS assignment_id | assignment_map.assignment_id |
| 20 | derived | - | vessel_id | - | vessel_map.vessel_id AS vessel_id | vessel_map.vessel_id |
| 21 | derived | - | workflow_status_id | - | ws_map.workflow_status_id AS workflow_status_id | ws_map.workflow_status_id |
| 22 | reviewed_at | - | is_verified | - | CASE WHEN s.reviewed_at IS NOT NULL THEN true ELSE false END AS is_verified | CASE WHEN s.reviewed_at IS NOT NULL THEN true ELSE false END |
| 23 | reviewed_at | - | verified_at | - | s.reviewed_at AS verified_at | s.reviewed_at |
| 24 | reviewer_id | - | verified_by_id | - | CASE WHEN s.reviewer_id IS NOT NULL AND s.reviewer_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN s.reviewer_id::uuid ELSE NULL END AS verified_by_id | CASE WHEN s.reviewer_id IS NOT NULL AND s.reviewer_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN s.reviewer_id::uuid ELSE NULL END |
| 25 | reviewer_comments | - | verification_notes | - | TRIM(COALESCE(s.reviewer_comments, '')) AS verification_notes | TRIM(COALESCE(s.reviewer_comments, '')) |
| 26 | deleted_at | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 'Inactive' ELSE 'Active' END AS status | CASE WHEN s.deleted_at IS NOT NULL THEN 'Inactive' ELSE 'Active' END |
| 27 | derived | - | tenant_id | - | v_default_tenant_id AS tenant_id | v_default_tenant_id |
| 28 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 29 | updated_at | - | updated_at | - | COALESCE(s.updated_at, NOW()) AS updated_at | COALESCE(s.updated_at, NOW()) |
| 30 | - | - | archived_at | - | NULL | NULL::timestamp |
| 31 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 32 | created_by_name, updated_by_name, deleted_at, deleted_by_id, updated_at, created_at, legacy_id, reviewed_at, reviewer_id, created_by_id, request_created_by_id, updated_by_id, status | - | audit_info | - | jsonb_build_object( 'notes', CASE WHEN s.created_by_name IS NOT NULL AND s.updated_by_name IS NOT NULL THEN 'Created by: ' || TRIM(s.created_by_name) || '; Updated by: ' || TRIM... | jsonb_build_object( 'notes', CASE WHEN s.created_by_name IS NOT NULL AND s.updated_by_name IS NOT NULL THEN 'Created by: ' || TRIM(s.created_by_name) || '; Updated by: ' || TRIM... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Reimbursement Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_categories_id_mapping AS
SELECT
            source_id::integer AS legacy_id,
            target_id AS new_id
        FROM dblink('smac_master_migration',
            'SELECT source_id, target_id
             FROM migration.table_mappings
             WHERE target_table = ''reimbursement_categories''
               AND target_db = current_database()
               AND source_id ~ ''^[0-9]+$'''  -- Only fetch rows where source_id is numeric
        ) AS t(source_id VARCHAR(100), target_id UUID);
```

### 2. Reimbursement Sub Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_sub_categories_id_mapping AS
SELECT
            source_id::integer AS legacy_id,
            target_id AS new_id
        FROM dblink('smac_master_migration',
            'SELECT source_id, target_id
             FROM migration.table_mappings
             WHERE target_table = ''reimbursement_sub_categories''
               AND target_db = current_database()'
        ) AS t(source_id VARCHAR(100), target_id UUID);
```

### 3. Reimbursement Types ID Mapping
**Purpose**: Create empty temp table if connection doesn
**Output columns**: `legacy_type_name, new_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE reimbursement_types_id_mapping AS
SELECT

            CASE
                WHEN UPPER(TRIM(rt.name)) = 'PRE JOINING' THEN 'Before Joining'
                WHEN UPPER(TRIM(rt.name)) = 'ON BOARDING' THEN 'On Boarding'
                ELSE rt.name
            END AS legacy_type_name,
            rt.id AS new_id
        FROM dblink('smac_master_migration',
            $dblink_query$SELECT id, name FROM crewing.reimbursement_types WHERE name IS NOT NULL$dblink_query$
        ) AS rt(id uuid, name text)
        WHERE rt.name IS NOT NULL;
```

### 4. Seafarers ID Mapping
**Output columns**: `crew_code, seafarer_id`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    TRIM(s.crew_code) AS crew_code,
    s.id AS seafarer_id
FROM public.seafarers s
INNER JOIN reimbursement_request_crew_codes rrc ON
    TRIM(UPPER(s.crew_code)) = TRIM(UPPER(rrc.crew_code))
WHERE s.crew_code IS NOT NULL
  AND TRIM(s.crew_code) != '';
```

### 5. Shore User Legacy ID Mapping
**Purpose**: Create empt
**Output columns**: `legacy_user_key, smac_user_id`
**migration.table_mappings**: `Users` → `users`

```sql
CREATE TEMP TABLE shore_user_legacy_to_uuid AS
SELECT DISTINCT ON (TRIM(m.source_id))
    TRIM(m.source_id) AS legacy_user_key,
    m.target_id AS smac_user_id
FROM migration.table_mappings m
WHERE m.target_table = 'users'
  AND m.target_schema = 'public'
  AND m.source_table = 'Users'
ORDER BY TRIM(m.source_id), m.migrated_at DESC NULLS LAST;
```

### 6. Seafarer Id Legacy For Relief Summary ID Mapping
**Purpose**: Map source type names to target type names:
**Output columns**: `legacy_seafarer_id, new_seafarer_id, crew_code`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_id_legacy_for_relief_summary AS
SELECT DISTINCT
            s.id AS legacy_seafarer_id,
            sim.seafarer_id AS new_seafarer_id,
            TRIM(UPPER(s.crew_code)) AS crew_code
        FROM dblink('synergy_seafarer',
            'SELECT id, crew_code FROM public.seafarers WHERE crew_code IS NOT NULL'
        ) AS s(id bigint, crew_code text)
        INNER JOIN seafarers_id_mapping sim ON TRIM(UPPER(sim.crew_code)) = TRIM(UPPER(s.crew_code));
```

### 7. Vessel Imo ID Mapping
**Output columns**: `imo_number, vessel_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT
            TRIM(v.imo_number)::text AS imo_number,
            v.id AS vessel_id
        FROM dblink('smac_master_migration',
            'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
        ) AS v(id uuid, imo_number text)
        WHERE v.imo_number IS NOT NULL AND TRIM(v.imo_number) != '';
```

### 8. Workflow Status ID Mapping
**Purpose**: Map crewCode from reimbursement_requests to seafarer UUID via seafarers table
**Output columns**: `workflow_status_id, workflow_status_name, workflow_status_code, workflow_status_value`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
            ws.id AS workflow_status_id,
            ws.name AS workflow_status_name,
            ws.code AS workflow_status_code,
            ws.workflow_status::integer AS workflow_status_value
        FROM dblink('smac_master_migration',
            $dblink_query$SELECT id, name, code, workflow_status FROM public.workflow_status WHERE workflow_status IS NOT NULL$dblink_query$
        ) AS ws(id uuid, name text, code text, workflow_status integer);
```

### 9. Pre Computed Assignment ID Mapping
**Output columns**: `reimbursement_item_id, frs.assignment_id, frs.relief_created_at, frs.contract_end_date`

```sql
CREATE TEMP TABLE pre_computed_assignment_id_mapping AS
SELECT DISTINCT ON (s.legacy_id)
        s.legacy_id AS reimbursement_item_id,
        frs.assignment_id,
        frs.relief_created_at,
        frs.contract_end_date
    FROM staging_reimbursement_request_items s

    INNER JOIN seafarer_id_legacy_for_relief_summary sil ON
        UPPER(sil.crew_code) = UPPER(TRIM(s.request_crew_code))
        AND s.request_crew_code IS NOT NULL
        AND TRIM(s.request_crew_code) != ''

    INNER JOIN pre_filtered_relief_summary frs ON
        frs.seafarer_id = sil.legacy_seafarer_id
        AND frs.vessel_imo_number = TRIM(s.request_vessel_imo_number)
        AND s.request_vessel_imo_number IS NOT NULL
        AND TRIM(s.request_vessel_imo_number) != ''

        AND s.created_at >= COALESCE(frs.relief_created_at, '1900-01-01'::timestamp)
        AND s.created_at <= COALESCE(frs.contract_end_date::timestamp, '9999-12-31'::timestamp)
    ORDER BY s.legacy_id, frs.relief_created_at DESC NULLS LAST;
```

### 10. Workflow Status Normalized ID Mapping
**Output columns**: `s.legacy_id, workflow_status_id`

```sql
CREATE TEMP TABLE workflow_status_normalized_mapping AS
SELECT
        s.legacy_id,
        COALESCE(
            ws_lookup.workflow_status_id,
            (SELECT id FROM default_workflow_status LIMIT 1),
            '00000000-0000-0000-0000-000000000000'::uuid
        ) AS workflow_status_id
    FROM staging_reimbursement_request_items s
    LEFT JOIN workflow_status_lookup ws_lookup ON
        UPPER(TRIM(ws_lookup.workflow_status_code)) =
        CASE
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'APPROVED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'approved' THEN 'APPROVED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'REJECTED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'rejected' THEN 'REJECTED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'FORWARDED' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'forwarded' THEN 'FORWARDED'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'INPROGRESS' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'in_progress' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'inprogress' THEN 'INPROGRESS'
            WHEN UPPER(TRIM(COALESCE(s.status, ''))) = 'REQUESTATTACHMENTS' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'request_attachments' OR LOWER(TRIM(COALESCE(s.status, ''))) = 'requestattachments' THEN 'REQUESTATTACHMENTS'
            ELSE NULL
        END;
```

Full migration context: `04-migration-scripts/crewing/seafarer_reimbursements_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_reimbursements_validation.sql` if available
- Run `06-rollback/crewing/seafarer_reimbursements_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
