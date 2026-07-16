# Table Mapping: relief_candidates → relief_candidates

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: relief_candidates
- **Source Script**: `04-migration-scripts/crewing/relief_candidates_migration.sql`


## Business Key

- **Business Key**: `seafarer_id`
- **Source (orchestration)**: Shortlisted Seafarers (`shortlisted_seafarers` → `relief_candidates`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates shortlisted_seafarers to relief_candidates. Maps seafarer_id (bigint) to seafarer_id (uuid) via migration.table_mappings. Gets vessel_id from seafarer_reliefs via relief_id. Preserves legacy UUID for id when available. Requires seafarers and seafarer_reliefs tables to be migrated first. CRITICAL: seafarer_reliefs must be enabled and migrated before relief_candidates, otherwise relief_vessel_mapping will be empty and all rows will be filtered out.

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE shore.relief_candidates` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_reliefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 8

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `relief_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `relief_vessel_mapping` | FK lookup | `legacy_relief_id`, `vessel_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_last_vessel_mapping` | FK lookup | `legacy_seafarer_id`, `last_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `relief_legacy_position_mapping` | FK lookup | `legacy_relief_id`, `legacy_position_id` | - | `synergy_manning` |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `position_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_master` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `relief_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_reliefs

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### `relief_vessel_mapping`

- **Output columns**: legacy_relief_id, vessel_id
- **migration.table_mappings**: target_table=seafarer_reliefs

```sql
CREATE TEMP TABLE relief_vessel_mapping AS
SELECT
    tm.source_id::bigint AS legacy_relief_id,
    sr.vessel_id AS vessel_id
FROM migration.table_mappings tm
INNER JOIN public.seafarer_reliefs sr ON sr.id = tm.target_id
WHERE tm.target_table = 'seafarer_reliefs'
  AND tm.target_db = current_database()
  AND sr.vessel_id IS NOT NULL;
```

### `seafarer_last_vessel_mapping`

- **Output columns**: legacy_seafarer_id, last_vessel_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_last_vessel_mapping AS
SELECT
    tm.source_id::bigint AS legacy_seafarer_id,
    s.last_vessel_id AS last_vessel_id
FROM migration.table_mappings tm
INNER JOIN public.seafarers s ON s.id = tm.target_id
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database()
  AND s.last_vessel_id IS NOT NULL;
```

### `relief_legacy_position_mapping`

- **Output columns**: legacy_relief_id, legacy_position_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_legacy_position_mapping AS
SELECT
    id AS legacy_relief_id,
    on_signer_position_id AS legacy_position_id
FROM dblink('synergy_manning',
    'SELECT id, on_signer_position_id FROM public.reliefs WHERE on_signer_position_id IS NOT NULL'
) AS r(id bigint, on_signer_position_id bigint);
```

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | DISTINCT ON (relief_id, seafarer_id) * | DISTINCT ON (relief_id, seafarer_id) * |
| 2 | - | - | relief_id | - | See source script | See source script |
| 3 | - | - | seafarer_id | - | See source script | See source script |
| 4 | - | - | vessel_id | - | See source script | See source script |
| 5 | - | - | position_id | - | See source script | See source script |
| 6 | - | - | evaluation_notes | - | See source script | See source script |
| 7 | - | - | union_compliance | - | See source script | See source script |
| 8 | - | - | recent_vessel_id | - | See source script | See source script |
| 9 | - | - | last_sign_off_date | - | See source script | See source script |
| 10 | - | - | available_from | - | See source script | See source script |
| 11 | - | - | preferred_contract_length | - | See source script | See source script |
| 12 | - | - | workflow_status_id | - | See source script | See source script |
| 13 | - | - | is_verified | - | See source script | See source script |
| 14 | - | - | verified_at | - | See source script | See source script |
| 15 | - | - | verified_by_id | - | See source script | See source script |
| 16 | - | - | verification_notes | - | See source script | See source script |
| 17 | - | - | priority_order | - | See source script | See source script |
| 18 | - | - | is_backup | - | See source script | See source script |
| 19 | - | - | communication_channel | - | See source script | See source script |
| 20 | - | - | notified_at | - | See source script | See source script |
| 21 | - | - | response_status | - | See source script | See source script |
| 22 | - | - | status | - | See source script | See source script |
| 23 | - | - | state | - | See source script | See source script |
| 24 | - | - | tenant_id | - | See source script | See source script |
| 25 | - | - | created_at | - | See source script | See source script |
| 26 | - | - | updated_at | - | See source script | See source script |
| 27 | - | - | archived_at | - | See source script | See source script |
| 28 | - | - | deleted_at | - | See source script | See source script |
| 29 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Relief ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_reliefs'`

```sql
CREATE TEMP TABLE relief_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_reliefs'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 3. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'' AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

### 4. Relief Vessel ID Mapping
**Output columns**: `legacy_relief_id, vessel_id`
**migration.table_mappings**: `target_table='seafarer_reliefs'`

```sql
CREATE TEMP TABLE relief_vessel_mapping AS
SELECT
    tm.source_id::bigint AS legacy_relief_id,
    sr.vessel_id AS vessel_id
FROM migration.table_mappings tm
INNER JOIN public.seafarer_reliefs sr ON sr.id = tm.target_id
WHERE tm.target_table = 'seafarer_reliefs'
  AND tm.target_db = current_database()
  AND sr.vessel_id IS NOT NULL;
```

### 5. Seafarer Last Vessel ID Mapping
**Output columns**: `legacy_seafarer_id, last_vessel_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_last_vessel_mapping AS
SELECT
    tm.source_id::bigint AS legacy_seafarer_id,
    s.last_vessel_id AS last_vessel_id
FROM migration.table_mappings tm
INNER JOIN public.seafarers s ON s.id = tm.target_id
WHERE tm.target_table = 'seafarers'
  AND tm.target_db = current_database()
  AND s.last_vessel_id IS NOT NULL;
```

### 6. Relief Legacy Position ID Mapping
**Output columns**: `legacy_relief_id, legacy_position_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_legacy_position_mapping AS
SELECT
    id AS legacy_relief_id,
    on_signer_position_id AS legacy_position_id
FROM dblink('synergy_manning',
    'SELECT id, on_signer_position_id FROM public.reliefs WHERE on_signer_position_id IS NOT NULL'
) AS r(id bigint, on_signer_position_id bigint);
```

### 7. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 8. Position ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE position_id_mapping AS
SELECT id::bigint AS legacy_id, identifier AS new_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.positions WHERE identifier IS NOT NULL'
) AS t(id bigint, identifier uuid);
```

Full migration context: `04-migration-scripts/crewing/relief_candidates_migration.sql`

## Validation

- Run `05-validation/crewing/relief_candidates_validation.sql` if available
- Run `06-rollback/crewing/relief_candidates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
