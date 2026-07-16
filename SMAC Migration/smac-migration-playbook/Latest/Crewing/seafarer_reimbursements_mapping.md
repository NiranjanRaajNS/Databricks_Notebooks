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

- Source: `synergy_crewwage.public.reimbursement_request_items` joined with parent `reimbursement_requests`
- `id` via `gen_random_uuid()` per batch row (performance — not `resolve_target_id()` per row)
- Mappings stored in bulk post-insert matching `audit_info->>'legacy_id'`
- `seafarer_id` from parent request `crewCode` via `seafarers_id_mapping`
- `reimbursement_type_id`, `category_id`, `subcategory_id` via master DB `table_mappings`
- `course_name` derived from `claim_note` or `request_type_name`; fallback `'Reimbursement'`
- `payment_status` integer from status text (PAID→2, APPROVED→1, else 0)
- `assignment_id`, `vessel_id` from pre-computed relief/vessel IMO lookups
- `workflow_status_id` from normalized status mapping
- `status` text: `deleted_at IS NOT NULL` → `'Inactive'`, else `'Active'`
- Batch processing (configurable batch size) with progress logging
- Requires `seafarers`, `reimbursement_categories`, `reimbursement_types` migrated first

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
| 1 | `id` (item) | bigint | `id` | uuid | `gen_random_uuid()` per row | Bulk mapping via `audit_info.legacy_id` post-insert |
| 2 | parent `crewCode` | text | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; nil UUID if unmapped | From parent `reimbursement_requests` |
| 3 | parent `request_type` | text | `reimbursement_type_id` | uuid | Map via `reimbursement_types_id_mapping` | Lookup: master `table_mappings` → `reimbursement_types` |
| 4 | `reimbursement_category_id` | integer | `category_id` | uuid | Map via `reimbursement_categories_id_mapping` | Lookup: master `table_mappings` |
| 5 | `reimbursement_sub_category_id` | integer | `subcategory_id` | uuid | Map via `reimbursement_sub_categories_id_mapping` | Lookup: master `table_mappings` |
| 6 | `claim_note`, `request_type_name` | text | `course_name` | text | `COALESCE(TRIM(claim_note), TRIM(request_type_name), 'Reimbursement')` | NOT NULL in SMAC |
| 7 | `claim_note` | text | `description` | text | `TRIM(COALESCE(claim_note, ''))` | Direct copy |
| 8 | `claim_amount` | numeric | `amount` | numeric(12,2) | `CAST(COALESCE(claim_amount, 0) AS numeric(12,2))` | Claimed amount |
| 9 | `approved_amount` | numeric | `approved_amount` | numeric(12,2) | `CAST(COALESCE(approved_amount, 0) AS numeric(12,2))` | Approved amount |
| 10 | `converted_currency_code` | text | `base_currency` | text | `TRIM(COALESCE(converted_currency_code, 'USD'))` | Default USD |
| 11 | `currency_code` | text | `claimed_currency` | text | `TRIM(COALESCE(currency_code, 'USD'))` | Default USD |
| 12 | `currency_rate_applied` | numeric | `exchange_rate` | numeric(12,2) | `CAST(COALESCE(currency_rate_applied, 1) AS numeric(12,2))` | Default 1 |
| 13 | `created_at` | timestamp | `expense_date` | timestamp without time zone | `COALESCE(created_at, NOW())` | Item creation date as expense date |
| 14 | — | — | `receipt_attachments` | uuid[] | Hardcoded `'{}'::uuid[]` | Empty array; attachments not migrated |
| 15 | `created_by_id` | text | `claimed_by` | uuid | Cast when valid UUID format; else `NULL` | From item record |
| 16 | `created_at` | timestamp | `claimed_on` | timestamp without time zone | `COALESCE(created_at, NOW())` | Claim timestamp |
| 17 | `status` | text | `payment_status` | integer | PAID→2; APPROVED→1; else 0 | Derived from status text pattern |
| 18 | `claim_note` | text | `remarks` | text | `TRIM(COALESCE(claim_note, ''))` | Duplicate of description source |
| 19 | relief summary join | uuid | `assignment_id` | uuid | From `pre_computed_assignment_id_mapping` | Nullable |
| 20 | vessel IMO join | uuid | `vessel_id` | uuid | From `vessel_imo_mapping` | Nullable |
| 21 | status normalization | uuid | `workflow_status_id` | uuid | From `workflow_status_normalized_mapping` | Per-item workflow status |
| 22 | `reviewed_at` | timestamp | `is_verified` | boolean | `reviewed_at IS NOT NULL` | Derived verification flag |
| 23 | `reviewed_at` | timestamp | `verified_at` | timestamp without time zone | Direct copy | Nullable |
| 24 | `reviewer_id` | text | `verified_by_id` | uuid | Cast when valid UUID format; else `NULL` | Reviewer user |
| 25 | `reviewer_comments` | text | `verification_notes` | text | `TRIM(COALESCE(reviewer_comments, ''))` | Review comments |
| 26 | `deleted_at` | timestamp | `status` | text | `deleted_at IS NOT NULL` → `'Inactive'`; else `'Active'` | Soft-delete drives status text |
| 27 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 28 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 29 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 30 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in source |
| 31 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 32 | audit fields + `legacy_id` | mixed | `audit_info` | jsonb | `jsonb_build_object()` — names in `notes`, `legacy_id` for mapping | Includes reviewer/workflow metadata |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** Parent request fields not joined into INSERT; item fields not listed above.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `reimbursement_categories`
- `reimbursement_types`
- `seafarers`

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
