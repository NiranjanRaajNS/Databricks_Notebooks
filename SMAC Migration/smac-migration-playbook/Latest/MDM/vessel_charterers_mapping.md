# Table Mapping: vessel_charterer_details → vessel_charterers

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_charterer_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_charterers
- **Source Script**: `04-migration-scripts/master/vessel_charterers_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_charterer_details`
- **New Path**: `smac_master_migration.vessel.vessel_charterers`

## Business Key

- **Composite Key**: (`vessel_id`, `charterer_id`)
- **Source (orchestration)**: Vessel Charterer Details (`vessel_charterer_details` → `vessel_charterers`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- `vessel_id` via `vessel_details` → `migration.table_mappings` (vessels)
- `charterer_id` matched from SAC `name` → `vessel.charterers.name`
- `vessel_revision_id` from active revision lookup or placeholder UUID
- Filter: requires valid vessel and charterer mapping (`WHERE` excludes unmatched)
- `status` hardcoded Active (0)
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.vessel_charterers` before insert (full table reload).
- Orchestration dependencies: `vessels`, `charterer_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `charterer_id_mapping` | FK lookup | `charterer_name`, `charterer_id` | - | - |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_charterer_details)'
) AS vd(id bigint, vessel_id bigint)
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### `charterer_id_mapping`

- **Output columns**: charterer_name, charterer_id

```sql
CREATE TEMP TABLE charterer_id_mapping AS
SELECT
    c.name as charterer_name,
    c.id as charterer_id
FROM vessel.charterers c;
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC uuid as SMAC id |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` through `vessel_details` | FK lookup; required for insert |
| 3 | `—` | — | `vessel_revision_id` | uuid | Active revision from `vessel_revision_id_mapping` or placeholder UUID | FK lookup |
| 4 | `name` | text | `charterer_id` | uuid | Match `vessel.charterers.name` via `charterer_id_mapping` | Required for insert |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) |  |
| 8 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) |  |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) | No status column in SAC |
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` with infinity guard | NOT NULL in SMAC |
| 11 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` with infinity guard | Direct copy with fallback |
| 12 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | Source `audit_info` not preserved; Pattern 4 |

**SAC columns not migrated:** `audit_info` — replaced with SYSTEM_USER_ID audit.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `charterer_types`
- `charterers`
- `vessel_revisions`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id FROM public.vessel_details WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_charterer_details)'
) AS vd(id bigint, vessel_id bigint)
LEFT JOIN migration.table_mappings tm
    ON tm.target_table = 'vessels'
    AND tm.target_db = current_database()
    AND tm.source_id = vd.vessel_id::text;
```

### 2. Charterer ID Mapping
**Output columns**: `charterer_name, charterer_id`

```sql
CREATE TEMP TABLE charterer_id_mapping AS
SELECT
    c.name as charterer_name,
    c.id as charterer_id
FROM vessel.charterers c;
```

### 3. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/master/vessel_charterers_migration.sql`

## Validation

- Run `05-validation/master/vessel_charterers_validation.sql` if available
- Run `06-rollback/master/vessel_charterers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
