# Table Mapping: vessel_ecdis_info → vessel_ecdis_types

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_ecdis_info
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_ecdis_types
- **Source Script**: `04-migration-scripts/master/vessel_ecdis_types_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_ecdis_info`
- **New Path**: `smac_master_migration.vessel.vessel_ecdis_types`

## Business Key

- **Composite Key**: (`vessel_id`, `ecdis_type_id`)
- **Source (orchestration)**: Vessel Ecdis Info (`vessel_ecdis_info` → `vessel_ecdis_types`)

## Migration Notes

- SAC `id` (bigint) → SMAC `id` via `migration.resolve_target_id()` with `p_target_id = NULL`
- `vessel_id` via `vessel_details` → vessels mapping (placeholder UUID when unmapped)
- `vessel_revision_id` from `vessel_details.identifier` → revision mapping
- `ecdis_type_id` via `ecdis_id` → `ecdis_types` mapping
- `status` derived from `deleted_at` only (Case 1)
- `DISTINCT ON (legacy_data.id)` prevents duplicate mappings
## Special Considerations

- Map status: legacy vessel_ecdis_info has no status column; use deleted_at only (Rule 2.2.1: deleted_at takes precedence)
- Script performs `TRUNCATE TABLE vessel.vessel_ecdis_types` before insert (full table reload).
- Orchestration dependencies: `vessels`, `ecdis_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `vessel_details_identifier`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_revision_id_mapping` | Drop t | `legacy_identifier_text`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | - |
| `ecdis_type_id_mapping` | Create lookup | `legacy_ecdis_type_id`, `new_ecdis_type_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, vessel_details_identifier, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    vd.identifier AS vessel_details_identifier,
    tm_vessel.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id, identifier
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_ecdis_info)'
) AS vd(id bigint, vessel_id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.target_table = 'vessels'
   AND tm_vessel.target_db = current_database()
   AND tm_vessel.source_id = vd.vessel_id::text;
```

### `vessel_revision_id_mapping`

- **Purpose**: Drop t
- **Output columns**: legacy_identifier_text, new_vessel_revision_id
- **migration.table_mappings**: target_table=vessel_revisions

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id AS legacy_identifier_text,
    tm.target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vessel_revisions'
  AND tm.target_db = current_database()
ORDER BY tm.source_id, tm.target_id;
```

### `ecdis_type_id_mapping`

- **Purpose**: Create lookup
- **Output columns**: legacy_ecdis_type_id, new_ecdis_type_id
- **migration.table_mappings**: target_table=ecdis_types

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint as legacy_ecdis_type_id,
    target_id::uuid as new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` or placeholder UUID | FK lookup |
| 3 | `—` | — | `vessel_revision_id` | uuid | Revision mapping from `vessel_details.identifier` | FK lookup |
| 4 | `ecdis_id` | bigint | `ecdis_type_id` | uuid | Map via `ecdis_type_id_mapping` or placeholder UUID | FK lookup |
| 5 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 |
| 6 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 7 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 8 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 9 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |
| 10 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 11 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 12 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |
| 13 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |

**SAC columns not migrated:** None from dblink SELECT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `ecdis_types`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, vessel_details_identifier, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    vd.identifier AS vessel_details_identifier,
    tm_vessel.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id, identifier
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_ecdis_info)'
) AS vd(id bigint, vessel_id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.target_table = 'vessels'
   AND tm_vessel.target_db = current_database()
   AND tm_vessel.source_id = vd.vessel_id::text;
```

### 2. Vessel Revision ID Mapping
**Purpose**: Drop t
**Output columns**: `legacy_identifier_text, new_vessel_revision_id`
**migration.table_mappings**: `target_table='vessel_revisions'`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id AS legacy_identifier_text,
    tm.target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vessel_revisions'
  AND tm.target_db = current_database()
ORDER BY tm.source_id, tm.target_id;
```

### 3. Ecdis Type ID Mapping
**Purpose**: Create lookup
**Output columns**: `legacy_ecdis_type_id, new_ecdis_type_id`
**migration.table_mappings**: `target_table='ecdis_types'`

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint as legacy_ecdis_type_id,
    target_id::uuid as new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_ecdis_types_migration.sql`

## Validation

- Run `05-validation/master/vessel_ecdis_types_validation.sql` if available
- Run `06-rollback/master/vessel_ecdis_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
