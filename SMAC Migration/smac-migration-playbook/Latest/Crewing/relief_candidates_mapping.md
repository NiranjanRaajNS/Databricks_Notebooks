# Table Mapping: relief_candidates → relief_candidates

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: shortlisted_seafarers, recommendation_lists
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: relief_candidates
- **Source Script**: `04-migration-scripts/crewing/relief_candidates_migration.sql`

- **Legacy Path**: `synergy_manning.public.shortlisted_seafarers`, `synergy_manning.public.recommendation_lists`
- **New Path**: `smac_crewing_migration.shore.relief_candidates`

## Business Key

- **Composite Key**: (`relief_id`, `seafarer_id`)
- **Source (orchestration)**: Shortlisted Seafarers (`shortlisted_seafarers` → `relief_candidates`)

## Migration Notes

- Dual source: `shortlisted_seafarers` UNION `recommendation_lists`; deduplicated `DISTINCT ON (relief_id, seafarer_id)`
- `id` via `migration.resolve_target_id()` — no UUID in SAC (`p_target_id = NULL`); separate source tables
- `vessel_id` from `relief_vessel_mapping` via migrated `seafarer_reliefs` — required (rows without vessel excluded)
- `state`: Shortlisted (2) from `shortlisted_seafarers`; Recommended (1) from `recommendation_lists`
- Filter: `deleted_at IS NULL`; parent relief `relief_state` not close/closed
- Requires `seafarers` and `seafarer_reliefs` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.relief_candidates` before insert (full table reload)
- CRITICAL: `seafarer_reliefs` must be migrated first or all rows filtered out
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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; source table is `shortlisted_seafarers` or `recommendation_lists` |
| 2 | `relief_id` | bigint | `relief_id` | uuid | Map via `relief_id_mapping`; placeholder empty GUID if not found | Lookup: `migration.table_mappings` (`seafarer_reliefs`) |
| 3 | `seafarer_id`, `recommended_seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; placeholder empty GUID if not found | `seafarer_id` from shortlisted; `recommended_seafarer_id` from recommendations |
| 4 | `relief_id` (via `seafarer_reliefs`) | bigint | `vessel_id` | uuid | Map via `relief_vessel_mapping` from migrated `seafarer_reliefs` | Required — rows without valid vessel excluded |
| 5 | `position_id`, `reliefs.on_signer_position_id` | bigint | `position_id` | uuid | Shortlisted: `position_id_mapping` on `position_id`; Recommendations: via `relief_legacy_position_mapping` | Lookup: `synergy_master.positions.identifier` |
| 6 | — | — | `evaluation_notes` | text | Hardcoded NULL | Not in SAC source |
| 7 | — | — | `union_compliance` | numeric | Hardcoded `0.0` | NOT NULL default; not in SAC source |
| 8 | `seafarers.last_vessel_id` | bigint | `recent_vessel_id` | uuid | Map via `seafarer_last_vessel_mapping` | Lookup: `migration.table_mappings` (`vessels`) |
| 9 | — | — | `last_sign_off_date` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 10 | — | — | `available_from` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 11 | — | — | `preferred_contract_length` | interval | Hardcoded NULL | Not in SAC source |
| 12 | — | — | `workflow_status_id` | uuid | Default APPROVED via `workflow_status_id_mapping` | Lookup: `public.workflow_status` |
| 13 | — | — | `is_verified` | boolean | Hardcoded `false` | NOT NULL default |
| 14 | — | — | `verified_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 15 | — | — | `verified_by_id` | uuid | Hardcoded NULL | Not in SAC source |
| 16 | — | — | `verification_notes` | text | Hardcoded NULL | Not in SAC source |
| 17 | — | — | `priority_order` | integer | Hardcoded NULL | Not in SAC source |
| 18 | —, `is_system_generated` | —, boolean | `is_backup` | boolean | Hardcoded `false` (shortlisted); `is_system_generated` (recommendations) | Source-specific mapping |
| 19 | — | — | `communication_channel` | text | Hardcoded NULL | Not in SAC source |
| 20 | — | — | `notified_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 21 | — | — | `response_status` | text | Hardcoded NULL | Not in SAC source |
| 22 | `status_code`, `status` | bigint, character varying | `status` | integer | Shortlisted: `status_code` or text map; Recommendations: text map only (Active=1, Disabled=2, etc.) | Integer enum: Active=1, Disabled=2, Archived=3, Deleted=4, Draft=5, Rejected=6 |
| 23 | — | — | `state` | integer | Hardcoded `2` (Shortlisted) or `1` (Recommended) | Distinguishes source table |
| 24 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 25 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 26 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 27 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 28 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Hardcoded NULL | Source filtered `WHERE deleted_at IS NULL` |
| 29 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names in `notes` | Standardized SMAC audit structure |

**SAC columns not migrated:** `state` (varchar on shortlisted_seafarers) — SMAC `state` is integer derived from source table, not SAC varchar column.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_reliefs`
- `seafarers`

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
