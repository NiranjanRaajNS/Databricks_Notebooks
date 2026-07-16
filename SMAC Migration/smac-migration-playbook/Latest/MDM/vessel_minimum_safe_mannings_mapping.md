# Table Mapping: vessel_minimum_safe_mannings → vessel_minimum_safe_mannings

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_minimum_safe_mannings
- **Source Script**: `04-migration-scripts/master/vessel_minimum_safe_mannings_migration.sql`

- **New Path**: `smac_master_migration.vessel.vessel_minimum_safe_mannings`

## Business Key

- **Business Key**: `vessel_id`
- **Source (orchestration)**: Vessels Minimum Safe Manning (`vessels_minimum_safe_manning` → `vessel_minimum_safe_mannings`)

## Migration Notes

- Source: `synergy_vessel.public.vessels_minimum_safe_manning` unpivoted by rank column
- SAC `identifier` + rank column → composite `source_id` for `migration.resolve_target_id()`
- Pre-migration duplicate UUID check on SAC `identifier` column
- 13 UNION ALL branches for rank columns (master, chief_officer, AB deck, etc.)
- `msm_position_id` via fuzzy name match on `public.msm_positions`
- Filter: `identifier IS NOT NULL`; per branch rank value NOT NULL (includes 0)
- `status` derived from `deleted_at` only (Case 1)
## Special Considerations

- Uses composite source_id (legacy_id || '|rank_column') for unpivoted rows to ensure unique, idempotent IDs
- Unpivots rank columns (master, chief_engineer, etc.) into individual rows
- Run schema discovery first to verify identifier/uuid columns exist and rank column names
- Script performs `TRUNCATE TABLE vessel.vessel_minimum_safe_mannings` before insert (full table reload).
- Orchestration dependencies: `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_details_to_vessels_mapping` | FK lookup | `legacy_vessel_details_id`, `legacy_vessel_id` | - | `synergy_vessel` |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `final_vessel_id_mapping` | Clea | `vdtvm.legacy_vessel_details_id`, `smac_vessel_id` | - | - |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |
| `msm_position_lookup` | Store in session | `msm_position_id`, `position_name_lower`, `position_code_lower`, `position_name`, `position_code` | - | - |

### `vessel_details_to_vessels_mapping`

- **Output columns**: legacy_vessel_details_id, legacy_vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessels_mapping AS
SELECT DISTINCT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessels_minimum_safe_manning WHERE vessel_id IS NOT NULL)'
) AS vd(
    id bigint,
    vessel_id bigint
);
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `final_vessel_id_mapping`

- **Purpose**: Clea
- **Output columns**: vdtvm.legacy_vessel_details_id, smac_vessel_id

```sql
CREATE TEMP TABLE final_vessel_id_mapping AS
SELECT
    vdtvm.legacy_vessel_details_id,
    vm.new_id AS smac_vessel_id
FROM vessel_details_to_vessels_mapping vdtvm
LEFT JOIN vessels_id_mapping vm ON vm.legacy_id = vdtvm.legacy_vessel_id;
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

### `msm_position_lookup`

- **Purpose**: Store in session
- **Output columns**: msm_position_id, position_name_lower, position_code_lower, position_name, position_code

```sql
CREATE TEMP TABLE msm_position_lookup AS
SELECT
    mp.id AS msm_position_id,
    LOWER(TRIM(mp.name)) AS position_name_lower,
    LOWER(TRIM(mp.code)) AS position_code_lower,
    mp.name AS position_name,
    mp.code AS position_code
FROM public.msm_positions mp
WHERE mp.name IS NOT NULL AND TRIM(mp.name) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier, rank column` | uuid, integer | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `identifier|rank_column` | One row per rank count |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `final_vessel_id_mapping` or placeholder UUID | FK lookup |
| 3 | `—` | — | `vessel_revision_id` | uuid | Active revision or placeholder UUID | FK lookup |
| 4 | `rank column name` | — | `msm_position_id` | uuid | Fuzzy match via `msm_position_lookup` on rank name | FK lookup |
| 5 | `master, chief_officer, ab_deck, etc.` | integer | `value` | integer | Direct copy of rank count | Unpivoted rank columns |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |
| 9 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) | Not sourced from SAC |
| 10 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | Source `status`/`audit_info` not propagated |

**SAC columns not migrated:** `status`, `audit_info` from source — not written to target beyond `deleted_at` status derivation.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.msm_positions`
- `vessel.vessel_revisions`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Details To Vessels ID Mapping
**Output columns**: `legacy_vessel_details_id, legacy_vessel_id`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_to_vessels_mapping AS
SELECT DISTINCT
    vd.id AS legacy_vessel_details_id,
    vd.vessel_id AS legacy_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessels_minimum_safe_manning WHERE vessel_id IS NOT NULL)'
) AS vd(
    id bigint,
    vessel_id bigint
);
```

### 2. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 3. Final Vessel ID Mapping
**Purpose**: Clea
**Output columns**: `vdtvm.legacy_vessel_details_id, smac_vessel_id`

```sql
CREATE TEMP TABLE final_vessel_id_mapping AS
SELECT
    vdtvm.legacy_vessel_details_id,
    vm.new_id AS smac_vessel_id
FROM vessel_details_to_vessels_mapping vdtvm
LEFT JOIN vessels_id_mapping vm ON vm.legacy_id = vdtvm.legacy_vessel_id;
```

### 4. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

### 5. Msm Position ID Mapping
**Purpose**: Store in session
**Output columns**: `msm_position_id, position_name_lower, position_code_lower, position_name, position_code`

```sql
CREATE TEMP TABLE msm_position_lookup AS
SELECT
    mp.id AS msm_position_id,
    LOWER(TRIM(mp.name)) AS position_name_lower,
    LOWER(TRIM(mp.code)) AS position_code_lower,
    mp.name AS position_name,
    mp.code AS position_code
FROM public.msm_positions mp
WHERE mp.name IS NOT NULL AND TRIM(mp.name) <> '';
```

Full migration context: `04-migration-scripts/master/vessel_minimum_safe_mannings_migration.sql`

## Validation

- Run `05-validation/master/vessel_minimum_safe_mannings_validation.sql` if available
- Run `06-rollback/master/vessel_minimum_safe_mannings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
