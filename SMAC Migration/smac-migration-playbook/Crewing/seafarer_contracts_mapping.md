# Table Mapping: seafarer_contracts → seafarer_contracts

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_contracts
- **Source Script**: `04-migration-scripts/crewing/seafarer_contracts_migration.sql`


## Migration Notes

- Uses uuid column from source table as id (preserves legacy UUID)
- Maps seafarer_id from seafarer_id (bigint) via migration.table_mappings
- Maps vessel_id from vessel_id (bigint) via migration.table_mappings (from smac_master_migration)
- Maps rank_id from rank_id (bigint) via migration.table_mappings
- Maps position_id from position_id (bigint) via migration.table_mappings
- For draft_contracts: uses seafarer_uuid if available, otherwise maps seafarer_id
- For draft_contracts: maps relief_id to relief_candidates_id via migration.table_mappings
- Extracts is_verified from verifiedBy text field
- Extracts user IDs from created_by_id, updated_by_id to audit_info
- Uses text values for status (default 'Active')
- Requires public.seafarers, vessels, ranks to be migrated first
- FILTER: Only migrates records where deleted_at IS NULL (all statuses including Closed and Void are migrated)
- Post-migration update script: Backfills ref_agreement_sets_id in seafarer_contracts table. Links each contract to its latest active contract_agreement_sets based on effective_date and created_at. Must run AFTER both seafarer_contracts and contract_agreement_sets migrations are complete.

## Special Considerations

- For draft_contracts: extracts start_date, end_date, vessel_id, rank_id from contract_basic_info JSONB
- Script performs `TRUNCATE TABLE public.seafarer_contracts` before insert (full table reload).
- Orchestration dependencies: `seafarer_contracts`, `contract_agreement_sets`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 8

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ranks_id_mapping` | Check for duplicate UUIDs in draft_contracts source table | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `positions_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `relief_candidates_id_mapping` | FK lookup | `legacy_relief_id`, `relief_candidates_id` | `migration.table_mappings` (see SQL) | - |
| `assignment_id_mapping` | Create lookup tables for fore | `legacy_vessel_contract_id`, `assignment_id` | - | - |
| `workflow_status_lookup` | FK lookup | `status_code`, `workflow_status_id` | - | `smac_master_migration` |
| `place_of_engagement_lookup` | Ranks lookup (from smac_master_migration) | `place_name`, `place_of_engagement_id` | - | `smac_master_migration` |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `ranks_id_mapping`

- **Purpose**: Check for duplicate UUIDs in draft_contracts source table
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `positions_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `relief_candidates_id_mapping`

- **Output columns**: legacy_relief_id, relief_candidates_id
- **migration.table_mappings**: target_table=seafarer_reliefs

```sql
CREATE TEMP TABLE relief_candidates_id_mapping AS
SELECT DISTINCT ON (relief_map.source_id::bigint)
    relief_map.source_id::bigint AS legacy_relief_id,
    rc.id AS relief_candidates_id
FROM migration.table_mappings relief_map
INNER JOIN public.seafarer_reliefs sr ON sr.id = relief_map.target_id
INNER JOIN shore.relief_candidates rc ON rc.relief_id = sr.id
WHERE relief_map.target_table = 'seafarer_reliefs'
  AND relief_map.target_db = current_database()
  AND relief_map.source_id ~ '^[0-9]+$'
ORDER BY relief_map.source_id::bigint, rc.created_at DESC NULLS LAST, rc.id;
```

### `assignment_id_mapping`

- **Purpose**: Create lookup tables for fore
- **Output columns**: legacy_vessel_contract_id, assignment_id

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id::bigint AS legacy_vessel_contract_id,
    rs.assignment_id AS assignment_id
FROM public.relief_summary rs
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### `workflow_status_lookup`

- **Output columns**: status_code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status'
) AS ws(code text, id uuid);
```

### `place_of_engagement_lookup`

- **Purpose**: Ranks lookup (from smac_master_migration)
- **Output columns**: place_name, place_of_engagement_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE place_of_engagement_lookup AS
SELECT
    poe.name::varchar(255) AS place_name,
    poe.id::uuid AS place_of_engagement_id
FROM dblink('smac_master_migration',
    'SELECT name, id FROM crewing.place_of_engagements'
) AS poe(name text, id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | * | * |
| 2 | - | - | seafarer_id | - | See source script | See source script |
| 3 | - | - | vessel_id | - | See source script | See source script |
| 4 | - | - | rank_id | - | See source script | See source script |
| 5 | - | - | position_id | - | See source script | See source script |
| 6 | - | - | assignment_id | - | See source script | See source script |
| 7 | - | - | origin | - | See source script | See source script |
| 8 | - | - | ref_agreement_sets_id | - | See source script | See source script |
| 9 | - | - | start_date | - | See source script | See source script |
| 10 | - | - | end_date | - | See source script | See source script |
| 11 | - | - | place_of_engagement_id | - | See source script | See source script |
| 12 | - | - | tenure_days | - | See source script | See source script |
| 13 | - | - | external_seaservice_id | - | See source script | See source script |
| 14 | - | - | workflow_status_id | - | See source script | See source script |
| 15 | - | - | is_verified | - | See source script | See source script |
| 16 | - | - | verified_at | - | See source script | See source script |
| 17 | - | - | verified_by_id | - | See source script | See source script |
| 18 | - | - | verification_notes | - | See source script | See source script |
| 19 | - | - | status | - | See source script | See source script |
| 20 | - | - | tenant_id | - | See source script | See source script |
| 21 | - | - | created_at | - | See source script | See source script |
| 22 | - | - | updated_at | - | See source script | See source script |
| 23 | - | - | archived_at | - | See source script | See source script |
| 24 | - | - | deleted_at | - | See source script | See source script |
| 25 | - | - | audit_info | - | See source script | See source script |
| 26 | - | - | relief_candidates_id | - | See source script | See source script |
| 27 | - | - | seafarer_confirmation_status | - | See source script | See source script |
| 28 | - | - | send_to_seafarer | - | See source script | See source script |
| 29 | - | - | reason_for_reject | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.relief_summary`
- `public.seafarers`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 3. Ranks ID Mapping
**Purpose**: Check for duplicate UUIDs in draft_contracts source table
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 4. Positions ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id         AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''positions'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 5. Relief Candidates ID Mapping
**Output columns**: `legacy_relief_id, relief_candidates_id`
**migration.table_mappings**: `target_table='seafarer_reliefs'`

```sql
CREATE TEMP TABLE relief_candidates_id_mapping AS
SELECT DISTINCT ON (relief_map.source_id::bigint)
    relief_map.source_id::bigint AS legacy_relief_id,
    rc.id AS relief_candidates_id
FROM migration.table_mappings relief_map
INNER JOIN public.seafarer_reliefs sr ON sr.id = relief_map.target_id
INNER JOIN shore.relief_candidates rc ON rc.relief_id = sr.id
WHERE relief_map.target_table = 'seafarer_reliefs'
  AND relief_map.target_db = current_database()
  AND relief_map.source_id ~ '^[0-9]+$'
ORDER BY relief_map.source_id::bigint, rc.created_at DESC NULLS LAST, rc.id;
```

### 6. Assignment ID Mapping
**Purpose**: Create lookup tables for fore
**Output columns**: `legacy_vessel_contract_id, assignment_id`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT DISTINCT ON (rs.contract_id)
    rs.contract_id::bigint AS legacy_vessel_contract_id,
    rs.assignment_id AS assignment_id
FROM public.relief_summary rs
WHERE rs.contract_id IS NOT NULL
  AND rs.assignment_id IS NOT NULL
  AND rs.assignment_id != '00000000-0000-0000-0000-000000000000'::uuid
ORDER BY rs.contract_id, rs.assignment_id;
```

### 7. Workflow Status ID Mapping
**Output columns**: `status_code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status'
) AS ws(code text, id uuid);
```

### 8. Place Of Engagement ID Mapping
**Purpose**: Ranks lookup (from smac_master_migration)
**Output columns**: `place_name, place_of_engagement_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE place_of_engagement_lookup AS
SELECT
    poe.name::varchar(255) AS place_name,
    poe.id::uuid AS place_of_engagement_id
FROM dblink('smac_master_migration',
    'SELECT name, id FROM crewing.place_of_engagements'
) AS poe(name text, id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_contracts_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_contracts_validation.sql` if available
- Run `06-rollback/crewing/seafarer_contracts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
