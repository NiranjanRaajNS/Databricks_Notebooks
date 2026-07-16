# Table Mapping: fleet_vessel_mapping → fld_fleet_vessels

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: fleet_vessel_mapping
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fld_fleet_vessels
- **Source Script**: `04-migration-scripts/master/fld_fleet_vessels_migration.sql`

- **Legacy Path**: `synergy_vessel.public.fleet_vessel_mapping`
- **New Path**: `smac_master_migration.vessel.fld_fleet_vessels`

## Business Key

- **Business Key**: `id` (UUID)
- **Source (orchestration)**: FLD Fleet Vessels (`fleet_vessel_mapping` → `fld_fleet_vessels`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `fleet_id` resolved via direct join to `vessel.fleets` or `migration.table_mappings` fallback
- `vessel_id` resolved via `vessel_details_mapping` (`vessel_details.identifier` → `vessel_details.vessel_id`) then `migration.table_mappings` (`vessels`)
- `vessel_revision_id` set to SAC `vessel_id` (vessel_details identifier UUID) — not looked up from `vessel_revisions`
- `legacy_status` from `COALESCE(status, audit_info->>'status')`
- `status` derived from `deleted_at` + `legacy_status` (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Rows excluded when fleet or vessel mapping cannot be resolved

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fld_fleet_vessels` before insert (full table reload)
- Orchestration dependencies: `fleets`, `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_details_mapping` | Resolve vessel_details identifier to legacy vessel bigint | `identifier`, `vessel_id` | - | `synergy_vessel` |

### `vessel_details_mapping`

- **Purpose**: Map `fleet_vessel_mapping.vessel_id` (vessel_details identifier UUID) to legacy vessel bigint for vessels lookup
- **Output columns**: identifier, vessel_id
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.identifier,
    vd.vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL
       AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID `id` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `fleet_id` | uuid | `fleet_id` | uuid | Join `vessel.fleets` on `id`; fallback `migration.table_mappings` (`fleets`) | Required — unmapped fleets excluded |
| 3 | `vessel_id` | uuid | `vessel_id` | uuid | `vessel_details_mapping` → `migration.table_mappings` (`vessels`) on `vessel_details.vessel_id` | SAC `vessel_id` is vessel_details identifier, not vessels.id |
| 4 | `vessel_id` | uuid | `vessel_revision_id` | uuid | Direct copy of SAC `vessel_id` | Uses legacy vessel_details identifier as revision id (not active revision lookup) |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 9 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 11 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 12 | — | — | `level` | numeric | Hardcoded NULL | Not in SAC source |
| 13 | — | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 14 | `deleted_at`, `status`, `audit_info` | timestamp without time zone, text, jsonb | `status` | integer | `legacy_status = COALESCE(status, audit_info->>'status')`; Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `legacy_status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — `deleted_at` takes precedence |
| 15 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 16 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 17 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | Standardized SMAC audit structure; no `legacy_id` (id preserved as `id`) |

**SAC columns not migrated:** `status` and `audit_info` status fields — used only for `status` integer derivation; SAC `audit_info` replaced with SMAC audit structure.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `fleets`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Details ID Mapping

**Purpose**: Resolve vessel_details identifier to legacy vessel bigint for vessels FK lookup

**Output columns**: `identifier, vessel_id`

**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_details_mapping AS
SELECT
    vd.identifier,
    vd.vessel_id
FROM dblink('synergy_vessel',
    'SELECT identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL
       AND vessel_id IS NOT NULL'
) AS vd(identifier uuid, vessel_id bigint);
```

Full migration context: `04-migration-scripts/master/fld_fleet_vessels_migration.sql`

## Validation

- Run `05-validation/master/fld_fleet_vessels_validation.sql` if available
- Run `06-rollback/master/fld_fleet_vessels_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
