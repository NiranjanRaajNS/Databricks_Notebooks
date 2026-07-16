# Table Mapping: vessel_contracts + reliefs → seafarer_vessel_assignments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: vessel_contracts (primary orchestration source) + reliefs (supplementary)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_vessel_assignments
- **Source Script**: `04-migration-scripts/crewing/seafarer_vessel_assignments_migration.sql`

- **Legacy Path**: `synergy_manning.public.vessel_contracts` + `synergy_manning.public.reliefs`
- **New Path**: `smac_crewing_migration.public.seafarer_vessel_assignments`

## Business Key

- **Business Key**: `contract_id`
- **Source (orchestration)**: Seafarer Vessel Assignments (`vessel_contracts` → `seafarer_vessel_assignments`)

## Migration Notes

- Combines data from `vessel_contracts` (contract dates, ports, status) and `reliefs` (relief states, documentation progress) via staging table `public.relief_summary`
- `relief_summary` built from planned reliefs (`reliever_seafarer_id`) FULL OUTER JOIN onboard reliefs (`relieving_seafarer_id`), LEFT JOIN `vessel_contracts` for contract fields
- `id` = `gen_random_uuid()` per row as `relief_summary.assignment_id` (not `migration.resolve_target_id()`)
- `INSERT ... ON CONFLICT (id) DO UPDATE` — no TRUNCATE; upsert pattern for repeated runs
- Pre-migration duplicate UUID check on `reliefs.uuid` column
- Repeated-migration detection keyed on `reliefs` as primary source table via `migration.check_existing_mapping()`
- `vessel_id` resolved by IMO join to `vessel.vessels` via dblink (`smac_master_migration`); legacy `vessel_id` bigint is not used
- `rank_id` / `position_id` from `COALESCE(contract_rank_id, rank_id)` and `COALESCE(contract_position_id, position_id)` mapped via `synergy_master` identifier lookups
- `seafarer_id` mapped from `COALESCE(reliever_seafarer_id, relieving_seafarer_id)` via `migration.table_mappings` (`seafarers`)
- Documentation statuses derived from `relief_progress_status` JSONB nodes + `contract_status` state machine
- `audit_info` stores `legacy_relief_id`, `legacy_onboard_relief_id`, `legacy_vessel_contract_id`, `seafarer_type` (`'reliever'`)
- Filter: `seafarer_id IS NOT NULL` and seafarer mapping must exist
- `contract_id` and `seafarer_relief_id` set to nil UUID / NULL at INSERT; backfilled by post-migration update scripts
- Requires `seafarers`, `vessels` (IMO lookup), and `seafarer_reliefs` migrated first

## Special Considerations

- Run schema discovery first to verify column structures
- `relief_summary` is created/populated during migration; skipped if table already has data
- `vessel_imo_mapping` temp table is created but main INSERT uses inline dblink join to `vessel.vessels` by IMO
- `seafarer_profile_mapping` and `joining_place_id_mapping` temp tables are created but not used in main INSERT
- Orchestration dependencies: `seafarers`, `vessels`, `seafarer_reliefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script.

**Total lookup tables:** 12

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_imo_mapping` | Vessel IMO cache (created; main INSERT uses inline dblink) | `vessel_id`, `imo_number` | - | `synergy_vessel` |
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `position_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `seafarer_profile_mapping` | FK lookup (created; unused in main INSERT) | `legacy_seafarer_id`, `rank_id`, `position_id` | `migration.table_mappings` (see SQL) | - |
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `sign_on_port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `ports` (via dblink) | `smac_master_migration` |
| `sign_off_port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `ports` (via dblink) | `smac_master_migration` |
| `joining_place_id_mapping` | FK lookup (created; unused in main INSERT) | `legacy_id`, `new_id` | `places` (via dblink) | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `code`, `workflow_status_id` | - | `smac_master_migration` |
| `assignment_stage_id_mapping` | FK lookup | `code`, `assignment_stage_id` | - | `smac_master_migration` |
| `assignment_type_mapping` | FK lookup | `assignment_type_id`, `relief_state_code` | - | `smac_master_migration` |

### `vessel_imo_mapping`

- **Output columns**: vessel_id, imo_number
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    v.imo_number
FROM dblink('synergy_vessel',
    'SELECT id, imo_number FROM public.vessels WHERE id IS NOT NULL'
) AS v(id bigint, imo_number varchar);
```

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### `position_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### `seafarer_profile_mapping`

- **Output columns**: legacy_seafarer_id, rank_id, position_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_profile_mapping AS
SELECT
    tm.source_id::bigint AS legacy_seafarer_id,
    s.rank_id AS rank_id,
    s.position_id AS position_id
FROM migration.table_mappings tm
INNER JOIN public.seafarers s ON s.id = tm.target_id
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database()
  AND s.rank_id IS NOT NULL;
```

### `contract_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_contracts

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `sign_on_port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ports
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_on_port_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### `sign_off_port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ports
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_port_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### `joining_place_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=places
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''places'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### `workflow_status_id_mapping`

- **Output columns**: code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT code, id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM public.workflow_status WHERE code IN (''SIGNED'', ''CLOSED'', ''DRAFT'')'
) AS t(id uuid, code varchar);
```

### `assignment_stage_id_mapping`

- **Output columns**: code, assignment_stage_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE assignment_stage_id_mapping AS
SELECT code, id AS assignment_stage_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.assignment_stages WHERE code IN (''SIGN_OFF'', ''SIGN_ON'', ''MATCHING'', ''REQUEST'', ''MATCH'', ''DOCUMENTATION'', ''ADD'', ''CANCELLED'', ''TRAVEL_PLANNING'', ''TRAVELLING'', ''FINALGOAHEAD_REQUESTED'')'
) AS t(id uuid, code varchar);
```

### `assignment_type_mapping`

- **Output columns**: assignment_type_id, relief_state_code
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE assignment_type_mapping AS
SELECT id AS assignment_type_id, code AS relief_state_code
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.assignment_types'
) AS t(id uuid, code varchar);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `relief_summary.assignment_id` (`gen_random_uuid()`) | Not idempotent; generated per relief_summary row |
| 2 | `reliever_seafarer_id` / `relieving_seafarer_id` (reliefs) | integer | `seafarer_id` | uuid | `COALESCE(reliever, relieving)` → `seafarer_id_mapping` | Required; unmapped rows excluded |
| 3 | `vessel_imo_number` (reliefs) | text | `vessel_id` | uuid | Join `vessel.vessels` by IMO via dblink; default nil UUID if unmapped | Not legacy `vessel_id` bigint |
| 4 | `assignment_rank_id` (relief_summary) | integer | `rank_id` | uuid | `COALESCE(contract_rank_id, rank_id)` → `rank_id_mapping`; default nil UUID | From relief_summary staging |
| 5 | `assignment_position_id` (relief_summary) | integer | `position_id` | uuid | `COALESCE(contract_position_id, position_id)` → `position_id_mapping` | Nullable if unmapped |
| 6 | `contract_id` (vessel_contracts via relief_summary) | integer | `contract_id` | uuid | `contract_id_mapping` at INSERT; backfilled post-migration | Nil UUID at INSERT if unmapped; see Post-Migration Updates |
| 7 | `start_date` (vessel_contracts) | date | `contract_start_date` | date | Direct copy via relief_summary | |
| 8 | `end_date` (vessel_contracts) | date | `contract_end_date` | date | Direct copy via relief_summary | |
| 9 | `sign_on_date` (vessel_contracts) | date | `sign_on_date` | date | Direct copy | |
| 10 | `sign_off_date` (vessel_contracts) | date | `sign_off_date` | date | Direct copy | |
| 11 | — | — | `joining_date` | timestamp without time zone | `NULL` | No source equivalent |
| 12 | `port_of_sign_on` (vessel_contracts) | integer | `sign_on_port_id` | uuid | `sign_on_port_id_mapping` | Nullable if unmapped |
| 13 | `port_of_sign_off` (vessel_contracts) | integer | `sign_off_port_id` | uuid | `sign_off_port_id_mapping` | Nullable if unmapped |
| 14 | `planned_relief_id`, `onboard_relief_id` (reliefs) | integer | `seafarer_relief_id` | uuid | `NULL` at INSERT; backfilled post-migration | See Post-Migration Updates |
| 15 | — | — | `assignment_reason` | text | `NULL` | No source equivalent |
| 16 | — | — | `job_assignment_notes` | text | `NULL` | Not extracted at INSERT (config notes `onsigner_remarks` JSONB as future source) |
| 17 | — | — | `is_emergency_replacement` | boolean | Hardcoded `false` | Config notes `relief_type` mapping as future enhancement |
| 18 | — | — | `is_inhouse_experience` | boolean | Hardcoded `false` | |
| 19 | — | — | `is_system_generated` | boolean | Hardcoded `true` | |
| 20 | — | — | `emergency_reason` | text | `NULL` | |
| 21 | `flag_documentation_state`, `contract_status` (reliefs/vessel_contracts) | text | `flag_documentation_status` | integer | State machine CASE (0=open, 1=started, 2=completed, 3=inforce) | Corrected by post-migration update script |
| 22 | `general_documentation_state`, `contract_status` | text | `general_documentation_status` | integer | State machine CASE (0=open, 1=started, 2=completed, 3=inforce) | Corrected by post-migration update script |
| 23 | `relief_progress_status` (JSON) | jsonb | `joining_documentation_status` | integer | `joining_documents` node: not_started→0, in_progress→1, completed→3 | `contract_status = inforce` → 3 |
| 24 | `relief_progress_status` / `reliever_travel_state` | text/json | `travel_documentation_status` | text | `travel_planning` node + legacy `travel_documentation_status` fallback | Values: Pending, In-Progress, InProgress, Approved, Completed |
| 25 | `relief_progress_status` (JSON) | jsonb | `reimbursement_status` | integer | `reimbursement` node: not_started→0, in_progress→1, completed→3 | |
| 26 | `relief_progress_status` (JSON) | jsonb | `medical_document_status` | integer | `medical_documents` node | |
| 27 | `relief_progress_status` (JSON) | jsonb | `predeparture_checklist_status` | integer | `predeparture_checklist` node | |
| 28 | — | — | `is_verified` | boolean | Hardcoded `false` | |
| 29 | — | — | `verified_at` | timestamp without time zone | `NULL` | |
| 30 | — | — | `verified_by_id` | uuid | `NULL` | |
| 31 | — | — | `verification_notes` | text | `NULL` | |
| 32 | `planned_relief_state` | text | `workflow_status_id` | uuid | Map relief state → CLOSED/DRAFT workflow status codes | Default nil UUID if unmapped |
| 33 | `planned_relief_state` / `onboard_relief_state` / `contract_status` | text | `assignment_stage_id` | uuid | Relief state + contract_status → assignment stage code | `inforce` → SIGN_ON; closed → SIGN_OFF |
| 34 | `planned_relief_state` | text | `assignment_type` | uuid | Match `assignment_types.code` via `assignment_type_mapping` | Nullable if unmapped |
| 35 | — | — | `compliance_status_id` | uuid | `NULL` | |
| 36 | `contract_status` (vessel_contracts) | text | `status` | character varying(50) | `closed`/`close` → `'Inactive'`; else `'Active'` | Based on contract_status, not relief state |
| 37 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 38 | — | — | `joining_place_id` | uuid | `NULL` | Lookup table created but unused at INSERT |
| 39 | `created_at` (reliefs) | timestamp without time zone | `created_at` | timestamp without time zone | `relief_created_at` from relief_summary | |
| 40 | — | — | `updated_at` | timestamp without time zone | `NOW()` | |
| 41 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 42 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Forced NULL at INSERT |


**SMAC columns not migrated at INSERT:** `joining_date`, `assignment_reason`, `job_assignment_notes`, `emergency_reason`, `compliance_status_id`, `joining_place_id`, `archived_at`, `deleted_at`, verification fields — NULL or hardcoded defaults. `contract_id` and `seafarer_relief_id` backfilled by post-migration update scripts.

**SAC columns not migrated:** `documentation_state`, `travel_replan_state`, `relief_deleted_at`, raw `vessel_id` (IMO used instead), `place_of_engagement` — present in relief_summary or source but not mapped to target columns at INSERT.

### Post-Migration Updates

#### `update_seafarer_vessel_assignments_contract_id.sql`

| Target Table | Target Column | Legacy Source (staging) | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|-------------------------|---------------|-------------|----------------|------------|
| `public.seafarer_vessel_assignments` | `contract_id` | `public.relief_summary` | `contract_id` | bigint | Primary: map via `table_mappings` (`vessel_contracts` → `seafarer_contracts`); fallback: `vessel_contracts.uuid = seafarer_contracts.id` | `contract_id` NULL or nil UUID; `relief_summary.contract_id > 0` |

**SAC origin:** `synergy_manning.public.vessel_contracts.id` stored in `relief_summary.contract_id` during assignments migration.

**Prerequisites:** Run after both `seafarer_vessel_assignments` and `seafarer_contracts` migrations.

#### `update_seafarer_vessel_assignments_relief_id.sql`

| Target Table | Target Column | Legacy Source (staging) | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|-------------------------|---------------|-------------|----------------|------------|
| `public.seafarer_vessel_assignments` | `seafarer_relief_id` | `public.relief_summary` | `planned_relief_id`, `onboard_relief_id` | bigint | Map `reliefs.id` → `seafarer_reliefs.id` via `table_mappings`; planned_relief_id first, then onboard_relief_id | `seafarer_relief_id` NULL; valid `assignment_id` |

**SAC origin:** `synergy_manning.public.reliefs.id`.

**Prerequisites:** Run after both `seafarer_vessel_assignments` and `seafarer_reliefs` migrations.

#### `update_seafarer_vessel_assignments_documentation_status.sql`

| Target Table | Target Column | Legacy Source (staging) | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|-------------------------|---------------|-------------|----------------|------------|
| `public.seafarer_vessel_assignments` | `flag_documentation_status` | `public.relief_summary` | `flag_documentation_status`, `contract_status` | text | Corrected CASE: open→0, documentation_started→1, general_documentation_completed/documentation_completed→**2**, inforce/approved→3 | Valid `assignment_id` |
| `public.seafarer_vessel_assignments` | `general_documentation_status` | `public.relief_summary` | `general_documentation_status`, `contract_status` | text | Same corrected CASE logic as flag_documentation_status | Valid `assignment_id` |

**Notes:** Corrects migration INSERT logic where `general_documentation_completed` / `documentation_completed` were mapped to 3 instead of 2. Uses `DISTINCT ON (planned_relief_id)` when building update staging data.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `vessels` (IMO lookup via `vessel.vessels`)
- `seafarer_reliefs` (for post-migration `seafarer_relief_id` backfill)

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables — see **ID Mappings** section above.

Key transformation patterns:
- **Vessel resolution**: IMO number from reliefs joined to `vessel.vessels.id` (uuid) via dblink, not legacy bigint `vessel_id`
- **Rank/position resolution**: Legacy bigint IDs from `synergy_master` mapped via `identifier` UUID preserved during ranks/positions migration
- **Port resolution**: Legacy port bigint IDs mapped via `migration.table_mappings` (`ports`) queried through dblink to `smac_master_migration`
- **Workflow/assignment stage**: Relief state strings mapped to master-data codes in `workflow_status`, `assignment_stages`, and `assignment_types`
- **Documentation statuses**: Multi-level CASE logic combining `contract_status`, string documentation states, and `relief_progress_status` JSONB nodes

Full migration context: `04-migration-scripts/crewing/seafarer_vessel_assignments_migration.sql`

Post-migration update scripts:
- `04-migration-scripts/crewing/update_seafarer_vessel_assignments_contract_id.sql`
- `04-migration-scripts/crewing/update_seafarer_vessel_assignments_relief_id.sql`
- `04-migration-scripts/crewing/update_seafarer_vessel_assignments_documentation_status.sql`

## Validation

- Run `05-validation/crewing/seafarer_vessel_assignments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_vessel_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
