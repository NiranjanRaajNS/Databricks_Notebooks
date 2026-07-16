# Table Mapping: seafarer_vessel_assignments → seafarer_vessel_assignments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_vessel_assignments
- **Source Script**: `04-migration-scripts/crewing/seafarer_vessel_assignments_migration.sql`


## Business Key

- **Business Key**: `contract_id`
- **Source (orchestration)**: Seafarer Vessel Assignments (`vessel_contracts` → `seafarer_vessel_assignments`)

## Migration Notes

- Combines data from vessel_contracts and reliefs tables
- Combines data from vessel_contracts (primary) and reliefs (supplementary) tables. Maps seafarer_Uuid (uuid) to seafarer_id (uuid). Maps vessel_id, rank_id, position_id, ports (bigint → uuid) via migration.table_mappings. Extracts job_assignment_notes from reliefs.onsigner_remarks JSONB. Maps relief_type to is_emergency_replacement. Uses standardized SMAC audit_info structure. Stores mappings for both vessel_contracts and reliefs sources. Requires seafarers, vessels, and seafarer_reliefs tables to be migrated first.

## Special Considerations

- Run schema discovery first to verify column structures
- Orchestration dependencies: `seafarers`, `vessels`, `seafarer_reliefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 12

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_imo_mapping` | FK lookup | `vessel_id`, `v.imo_number` | - | `synergy_vessel` |
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | Execute the CRE | `legacy_id`, `new_id` | - | `synergy_master` |
| `position_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |
| `seafarer_profile_mapping` | FK lookup | `legacy_seafarer_id`, `rank_id`, `position_id` | `migration.table_mappings` (see SQL) | - |
| `contract_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `sign_on_port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `sign_off_port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `joining_place_id_mapping` | Vessel mapping: Direct join with vessel.vessels using imo_number (no temp table needed) | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `code`, `workflow_status_id` | - | `smac_master_migration` |
| `assignment_stage_id_mapping` | FK lookup | `code`, `assignment_stage_id` | - | `smac_master_migration` |
| `assignment_type_mapping` | FK lookup | `assignment_type_id`, `relief_state_code` | - | `smac_master_migration` |

### `vessel_imo_mapping`

- **Output columns**: vessel_id, v.imo_number
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

- **Purpose**: Execute the CRE
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
- **migration.table_mappings**: target_table=
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
- **migration.table_mappings**: target_table=
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

- **Purpose**: Vessel mapping: Direct join with vessel.vessels using imo_number (no temp table needed)
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
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
| 1 | derived | - | id | - | new_data.id AS id | new_data.id |
| 2 | derived | - | seafarer_id | - | new_data.seafarer_id | new_data.seafarer_id |
| 3 | derived | - | vessel_id | - | new_data.vessel_id | new_data.vessel_id |
| 4 | derived | - | rank_id | - | new_data.rank_id | new_data.rank_id |
| 5 | derived | - | position_id | - | new_data.position_id | new_data.position_id |
| 6 | derived | - | contract_id | - | new_data.contract_id | new_data.contract_id |
| 7 | derived | - | contract_start_date | - | new_data.contract_start_date | new_data.contract_start_date |
| 8 | derived | - | contract_end_date | - | new_data.contract_end_date | new_data.contract_end_date |
| 9 | derived | - | sign_on_date | - | new_data.sign_on_date | new_data.sign_on_date |
| 10 | derived | - | sign_off_date | - | new_data.sign_off_date | new_data.sign_off_date |
| 11 | derived | - | joining_date | - | new_data.joining_date | new_data.joining_date |
| 12 | derived | - | sign_on_port_id | - | new_data.sign_on_port_id | new_data.sign_on_port_id |
| 13 | derived | - | sign_off_port_id | - | new_data.sign_off_port_id | new_data.sign_off_port_id |
| 14 | derived | - | seafarer_relief_id | - | new_data.seafarer_relief_id | new_data.seafarer_relief_id |
| 15 | derived | - | assignment_reason | - | new_data.assignment_reason | new_data.assignment_reason |
| 16 | derived | - | job_assignment_notes | - | new_data.job_assignment_notes | new_data.job_assignment_notes |
| 17 | derived | - | is_emergency_replacement | - | new_data.is_emergency_replacement | new_data.is_emergency_replacement |
| 18 | derived | - | emergency_reason | - | new_data.emergency_reason | new_data.emergency_reason |
| 19 | derived | - | is_inhouse_experience | - | new_data.is_inhouse_experience | new_data.is_inhouse_experience |
| 20 | derived | - | is_system_generated | - | new_data.is_system_generated | new_data.is_system_generated |
| 21 | derived | - | flag_documentation_status | - | new_data.flag_documentation_status | new_data.flag_documentation_status |
| 22 | derived | - | general_documentation_status | - | new_data.general_documentation_status | new_data.general_documentation_status |
| 23 | derived | - | joining_documentation_status | - | new_data.joining_documentation_status | new_data.joining_documentation_status |
| 24 | derived | - | travel_documentation_status | - | new_data.travel_documentation_status | new_data.travel_documentation_status |
| 25 | derived | - | reimbursement_status | - | new_data.reimbursement_status | new_data.reimbursement_status |
| 26 | derived | - | medical_document_status | - | new_data.medical_document_status | new_data.medical_document_status |
| 27 | derived | - | predeparture_checklist_status | - | new_data.predeparture_checklist_status | new_data.predeparture_checklist_status |
| 28 | derived | - | is_verified | - | new_data.is_verified | new_data.is_verified |
| 29 | derived | - | verified_at | - | new_data.verified_at | new_data.verified_at |
| 30 | derived | - | verified_by_id | - | new_data.verified_by_id | new_data.verified_by_id |
| 31 | derived | - | verification_notes | - | new_data.verification_notes | new_data.verification_notes |
| 32 | derived | - | workflow_status_id | - | new_data.workflow_status_id | new_data.workflow_status_id |
| 33 | derived | - | assignment_stage_id | - | new_data.assignment_stage_id | new_data.assignment_stage_id |
| 34 | derived | - | assignment_type | - | new_data.assignment_type | new_data.assignment_type |
| 35 | derived | - | compliance_status_id | - | new_data.compliance_status_id | new_data.compliance_status_id |
| 36 | derived | - | status | - | new_data.status | new_data.status |
| 37 | derived | - | tenant_id | - | new_data.tenant_id | new_data.tenant_id |
| 38 | derived | - | joining_place_id | - | new_data.joining_place_id | new_data.joining_place_id |
| 39 | derived | - | created_at | - | new_data.created_at AS created_at | new_data.created_at |
| 40 | derived | - | updated_at | - | new_data.updated_at AS updated_at | new_data.updated_at |
| 41 | derived | - | archived_at | - | new_data.archived_at | new_data.archived_at |
| 42 | derived | - | deleted_at | - | new_data.deleted_at | new_data.deleted_at |
| 43 | derived | - | audit_info | - | new_data.audit_info | new_data.audit_info |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Imo ID Mapping
**Output columns**: `vessel_id, v.imo_number`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    v.imo_number
FROM dblink('synergy_vessel',
    'SELECT id, imo_number FROM public.vessels WHERE id IS NOT NULL'
) AS v(id bigint, imo_number varchar);
```

### 2. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 3. Rank ID Mapping
**Purpose**: Execute the CRE
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### 4. Position ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

### 5. Seafarer Profile ID Mapping
**Output columns**: `legacy_seafarer_id, rank_id, position_id`
**migration.table_mappings**: `target_table='seafarers'`

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

### 6. Contract ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_contracts'`

```sql
CREATE TEMP TABLE contract_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_contracts'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 7. Sign On Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_on_port_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### 8. Sign Off Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE sign_off_port_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### 9. Joining Place ID Mapping
**Purpose**: Vessel mapping: Direct join with vessel.vessels using imo_number (no temp table needed)
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE joining_place_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''places'''
) AS t(source_id varchar, target_id uuid)
WHERE source_id ~ '^[0-9]+$';
```

### 10. Workflow Status ID Mapping
**Output columns**: `code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT code, id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM public.workflow_status WHERE code IN (''SIGNED'', ''CLOSED'', ''DRAFT'')'
) AS t(id uuid, code varchar);
```

### 11. Assignment Stage ID Mapping
**Output columns**: `code, assignment_stage_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE assignment_stage_id_mapping AS
SELECT code, id AS assignment_stage_id
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.assignment_stages WHERE code IN (''SIGN_OFF'', ''SIGN_ON'', ''MATCHING'', ''REQUEST'', ''MATCH'', ''DOCUMENTATION'', ''ADD'', ''CANCELLED'', ''TRAVEL_PLANNING'', ''TRAVELLING'', ''FINALGOAHEAD_REQUESTED'')'
) AS t(id uuid, code varchar);
```

### 12. Assignment Type ID Mapping
**Output columns**: `assignment_type_id, relief_state_code`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE assignment_type_mapping AS
SELECT id AS assignment_type_id, code AS relief_state_code
FROM dblink('smac_master_migration',
    'SELECT id, code FROM crewing.assignment_types'
) AS t(id uuid, code varchar);
```

Full migration context: `04-migration-scripts/crewing/seafarer_vessel_assignments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_vessel_assignments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_vessel_assignments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
