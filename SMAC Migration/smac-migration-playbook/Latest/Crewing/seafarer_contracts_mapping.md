# Table Mapping: seafarer_contracts → seafarer_contracts

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: vessel_contracts, draft_contracts
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_contracts
- **Source Script**: `04-migration-scripts/crewing/seafarer_contracts_migration.sql`

- **Legacy Path**: `synergy_manning.public.vessel_contracts`, `synergy_manning.public.draft_contracts`
- **New Path**: `smac_crewing_migration.public.seafarer_contracts`

## Business Key

- **Business Key**: `uuid`
- **Source (orchestration)**: Seafarer Contracts (`vessel_contracts` → `seafarer_contracts`)

## Migration Notes

- Dual source: `vessel_contracts` UNION `draft_contracts`; `DISTINCT ON (id)` per source
- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` (`vessel_contracts`); `draft_contracts` uses `id` as UUID
- `vessel_contracts` filtered: `uuid IS NOT NULL`, `deleted_at IS NULL`, must exist in `relief_summary.contract_id`
- `draft_contracts` filtered: `deleted_at IS NULL`; dates/FKs extracted from `contract_basic_info` JSONB
- FK lookups: `seafarers_id_mapping`, `vessels_id_mapping`, `ranks_id_mapping`, `positions_id_mapping`
- `status` text: Active/Inactive based on `deleted_at` and CLOSED status
- `workflow_status_id` mapped from SAC `status` via `workflow_status_lookup`
- Pre-migration duplicate UUID check on `vessel_contracts.uuid`
- Post-migration: `ref_agreement_sets_id` backfilled after `contract_agreement_sets` migration

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_contracts` before insert (full table reload)
- Orchestration dependencies: `seafarers`, `vessels`, `ranks`, `positions`, `relief_summary`, `relief_candidates`, `contract_agreement_sets`

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
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source table `vessel_contracts` or `draft_contracts` | `vessel_contracts`: `p_target_id = uuid`; `draft_contracts`: `p_target_id = id` |
| 2 | `seafarer_Uuid`, `seafarer_id`, `seafarer_uuid` | uuid, bigint | `seafarer_id` | uuid | Vessel: prefer `seafarer_Uuid`, else `seafarers_id_mapping`; Draft: prefer `seafarer_uuid`, else mapping; empty GUID fallback | Source-specific UUID preference |
| 3 | `vessel_id`, `contract_basic_info` | bigint, jsonb | `vessel_id` | uuid | Vessel: `vessels_id_mapping`; Draft: extract `VesselInfo.Id` from JSONB; empty GUID fallback | Lookup: `migration.table_mappings` (`vessels`) |
| 4 | `rank_id`, `contract_basic_info` | bigint, jsonb | `rank_id` | uuid | Vessel: `ranks_id_mapping`; Draft: extract `SeafarerInfo.RankId` from JSONB; empty GUID fallback | Lookup: `migration.table_mappings` (`ranks`) |
| 5 | `position_id`, `contract_basic_info` | bigint, jsonb | `position_id` | uuid | Vessel: `positions_id_mapping`; Draft: extract `SeafarerInfo.PositionId` from JSONB | Nullable; lookup: `positions` |
| 6 | `relief_summary.contract_id` | bigint | `assignment_id` | uuid | Map via `assignment_id_mapping` from `relief_summary` | Vessel contracts only; NULL for drafts |
| 7 | `origin` | text | `origin` | text | `TRIM(origin)` when non-empty; else NULL | Vessel contracts only; NULL for drafts |
| 8 | `ref_agreement_id` | character varying | `ref_agreement_sets_id` | uuid | Hardcoded NULL | Post-migration backfill from `contract_agreement_sets` |
| 9 | `start_date`, `contract_basic_info` | timestamp, jsonb | `start_date` | timestamp without time zone | Vessel: direct; Draft: `contract_basic_info.StartDate` with fallbacks | NOT NULL in SMAC |
| 10 | `end_date`, `contract_basic_info` | timestamp, jsonb | `end_date` | timestamp without time zone | Vessel: direct; Draft: `contract_basic_info.EndDate` with 6-month fallbacks | NOT NULL in SMAC |
| 11 | `place_of_engagement`, `contract_basic_info` | text, jsonb | `place_of_engagement_id` | uuid | Match name via `place_of_engagement_lookup` | Vessel: `place_of_engagement`; Draft: `PlaceOfEngagement` from JSONB |
| 12 | `start_date`, `end_date` | timestamp | `tenure_days` | integer | `(end_date::date - start_date::date)` | Calculated days between start and end |
| 13 | `external_seaservice_Id` | text | `external_seaservice_id` | text | `NULLIF(TRIM(external_seaservice_Id), '')` | Vessel contracts only; NULL for drafts |
| 14 | `status` | character varying | `workflow_status_id` | uuid | Map SAC status to `workflow_status.code` via `workflow_status_lookup` | e.g. SIGNED, CLOSED, INFORCE, DRAFT; empty GUID fallback |
| 15 | `verifiedBy` | text | `is_verified` | boolean | `true` when `verifiedBy` non-empty; else `false` | Vessel contracts only; drafts hardcoded `false` |
| 16 | `verifiedOn` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | Vessel contracts only; NULL for drafts |
| 17 | — | — | `verified_by_id` | uuid | Hardcoded NULL | Not parsed from `verifiedBy` text |
| 18 | — | — | `verification_notes` | text | Hardcoded NULL | Not in SAC source |
| 19 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | text | `deleted_at IS NOT NULL` or CLOSED → Inactive; else Active | Text status (not integer enum) |
| 20 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 21 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 22 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 23 | `status`, `updated_at` | character varying, timestamp | `archived_at` | timestamp without time zone | Set to `updated_at` when status is CLOSED; else NULL | Archive timestamp for closed contracts |
| 24 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Source filtered `WHERE deleted_at IS NULL` |
| 25 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name`, `deleted_by_id`, `deleted_by_name` | varchar/uuid | `audit_info` | jsonb | `migration.build_audit_info()` — IDs and names in `notes` | Drafts include `deleted_by_id`/`deleted_by_name` |
| 26 | `relief_id` | bigint | `relief_candidates_id` | uuid | Map via `relief_candidates_id_mapping` |  |
| 27 | `status` | character varying | `work_flow_status_id` | text | `status column from SAC vessel_contracts table mapping to SMAC Master db workflow_statuses id ` |  |
| 28 | `-` | character varying | `send_to_seafarer` | boolean | `true` when status is SENDTOSEAFARER; else `false` | |
| 29 | `reason` | text | `reason_for_reject` | text | `NULLIF(TRIM(reason), '')` |  |

**SAC columns not migrated:** `ref_agreement_id`, `remarks` (vessel_contracts); `url`, `poseidon_file_info`, `poseidon_family_info` (draft_contracts) — not inserted into SMAC.

**Post-migration (not from column mapping):** `ref_agreement_sets_id` backfilled after `contract_agreement_sets` migration.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `vessels`
- `ranks`
- `positions`
- `relief_summary` (from `seafarer_vessel_assignments`)
- `relief_candidates` (for draft `relief_candidates_id`)
- `contract_agreement_sets` (post-migration backfill of `ref_agreement_sets_id`)

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
