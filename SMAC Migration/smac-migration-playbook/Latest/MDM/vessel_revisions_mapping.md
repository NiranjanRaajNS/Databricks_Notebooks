# Table Mapping: vessel_details → vessel_revisions

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revisions
- **Source Script**: `04-migration-scripts/master/vessel_revisions_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details`
- **New Path**: `smac_master_migration.vessel.vessel_revisions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Revisions (`vessel_details` → `vessel_revisions`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `vessel_id` mapped via `vessel_id_mapping` (`vessel_details.vessel_id` bigint → `vessel.vessels.id` uuid)
- `flag_id` via `flag_id_mapping`; `registered_port_id` via `port_id_mapping` (`port_id` → `port_of_registry`)
- `class_id` via `class_id_mapping` (`vessel_class_id` → `classes`)
- `code` from `vessel_code` or fallback `imo_number`
- `revision_status` mapped from SAC `status` (ACTIVE→5, INACTIVE→7, DRAFT→0, ACTIVATIONPENDING→9, HANDOVERPENDING→3, etc.)
- `status` (integer) separate from `revision_status` — derived from `deleted_at` + `status` (Case 2)
- `is_registered_owner_and_signing_entity_same` uses `bare_boat_owner_id_mapping`
- Pre-migration duplicate UUID check on SAC `identifier` column
- Requires `vessels`, `flags`, `port_of_registry`, `classes` migrated first

## Special Considerations

- Rule 2.2.1 Case 2: `deleted_at` takes precedence over `status`
- Script performs `TRUNCATE TABLE vessel.vessel_revisions` before insert (full table reload)
- Post-migration UPDATE sets `is_bank_account_present` on `vessel_revision_owners` from SAC `is_bank_account_present`
- Orchestration dependencies: `vessels`, `flags`, `port_of_registry`, `classes`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `flag_id_mapping` | Check for duplicate UUIDs in source table | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `port_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `class_id_mapping` | FK lookup | `legacy_class_id`, `new_class_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `bare_boat_owner_id_mapping` | FK lookup | `owner_id`, `owner_identifier` | `?.?.vessel_bare_boat_owner` → `?.?.owners` | - |

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `flag_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=flags
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    tm.target_id AS new_id
FROM migration.table_mappings tm
JOIN dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags'
) AS f(
    id bigint,
    identifier uuid
) ON f.identifier::text = tm.source_id
WHERE tm.target_table = 'flags'
  AND tm.target_db = current_database()
UNION
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    f.identifier::uuid AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags'
) AS f(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'flags'
      AND tm.target_db = current_database()
      AND tm.source_id = f.identifier::text
);
```

### `port_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=port_of_registry
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT ON (legacy_port.id)
    legacy_port.id::bigint AS legacy_id,
    por_map.target_id AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.ports'
) AS legacy_port(id bigint, identifier uuid)
JOIN migration.table_mappings por_map
    ON por_map.source_id = legacy_port.identifier::text
    AND por_map.target_table = 'port_of_registry'
    AND por_map.target_db = current_database()
ORDER BY legacy_port.id, por_map.target_id;
```

### `class_id_mapping`

- **Output columns**: legacy_class_id, new_class_id
- **migration.table_mappings**: target_table=classes
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE class_id_mapping AS
SELECT
    source_id::bigint AS legacy_class_id,
    target_id AS new_class_id
FROM migration.table_mappings
WHERE target_table = 'classes'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS legacy_class_id,
    vc.identifier::uuid AS new_class_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_classes'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'classes'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### `bare_boat_owner_id_mapping`

- **Output columns**: owner_id, owner_identifier
- **migration.table_mappings**: source_table=vessel_bare_boat_owner, target_table=owners

```sql
CREATE TEMP TABLE bare_boat_owner_id_mapping AS
SELECT
    tm.source_id::bigint AS owner_id,
    tm.target_id::uuid AS owner_identifier
FROM migration.table_mappings tm
WHERE tm.source_table = 'vessel_bare_boat_owner'
  AND tm.target_table = 'owners'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `COALESCE(identifier::text, id::text)`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `vessel_id` | integer | `vessel_id` | uuid | Map via `vessel_id_mapping` | INNER JOIN required — rows without vessel mapping are excluded |
| 3 | `vessel_code`, `imo_number` | character varying(6), bigint | `code` | text | `COALESCE(NULLIF(TRIM(vessel_code), ''), imo_number::text)` | Business key; prefers `vessel_code` over `imo_number` |
| 4 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 5 | `mmsi` | bigint | `mmsi` | text | Cast to text when not NULL; else NULL | Type conversion bigint → text |
| 6 | `call_sign` | character varying(7) | `call_sign` | text | `TRIM(call_sign)` when non-empty; else NULL | Whitespace trimmed |
| 7 | — | — | `insurance_pi_id` | uuid | Hardcoded NULL | P&I insurance not migrated (varchar→uuid mapping removed) |
| 8 | — | — | `insurance_hm_id` | uuid | Hardcoded NULL | H&M insurance not migrated (varchar→uuid mapping removed) |
| 9 | `takeover_date` | timestamp without time zone | `takeover_on` | timestamp without time zone | Direct copy | SAC `takeover_date` renamed to `takeover_on` |
| 10 | `handover_date` | timestamp without time zone | `handover_on` | timestamp without time zone | Direct copy | SAC `handover_date` renamed to `handover_on` |
| 11 | `flag_id` | bigint | `flag_id` | uuid | Map via `flag_id_mapping` | Lookup: `migration.table_mappings` (`flags`) + `synergy_vessel.flags.identifier` fallback |
| 12 | `port_id` | bigint | `registered_port_id` | uuid | Map via `port_id_mapping` | SAC `port_id` → SMAC `registered_port_id`; lookup via `port_of_registry` mappings |
| 13 | `vessel_class_id` | bigint | `class_id` | uuid | Map via `class_id_mapping` | Lookup: `migration.table_mappings` (`classes`) + `vessel_classes.identifier` fallback |
| 14 | — | — | `skin_friction_reduction` | text | Hardcoded NULL | No SAC source column |
| 15 | — | — | `last_drydock` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 16 | — | — | `silicone_paint_applied_on` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 17 | — | — | `last_uw_coating_application` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 18 | — | — | `surface_preparation` | text | Hardcoded NULL | No SAC source column |
| 19 | — | — | `last_uw_inspection` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 20 | — | — | `intended_next_coating_application` | text | Hardcoded NULL | No SAC source column |
| 21 | — | — | `last_hull_cleaning` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 22 | — | — | `uw_coating_paint` | text | Hardcoded NULL | No SAC source column |
| 23 | — | — | `last_propeller_polishing` | timestamp without time zone | Hardcoded NULL | No SAC source column |
| 24 | — | — | `uw_coating` | text | Hardcoded NULL | No SAC source column |
| 25 | `official_number` | character varying | `official_number` | text | `TRIM(official_number)` when non-empty; else NULL | Direct copy with validation |
| 26 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 27 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 28 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 29 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 30 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 31 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 32 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 33 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; names from SAC `audit_info` in `notes` | Pattern 4 — no `legacy_id` (identifier preserved as `id`) |
| 34 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name)) - 1` | Sequential hierarchy index sorted by revision name |
| 35 | `takeover_date` | timestamp without time zone | `effective_date` | timestamp without time zone | Direct copy of `takeover_date` | Same value as `takeover_on` |
| 36 | — | — | `parent_revision_id` | uuid | Hardcoded NULL | Not in SAC source |
| 37 | `status` | character varying | `revision_status` | integer | Map SAC status text: DRAFT→0, ACTIVE→5, INACTIVE→7, ACTIVATIONPENDING→9, HANDOVERPENDING→3, TAKEOVERPENDING→1, TRANSFERPENDING→2; default 0 | NOT NULL; separate from SMAC `status` column |
| 38 | — | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 39 | `deleted_at`, `status` | timestamp without time zone, character varying | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 40 | — | — | `workflow_status` | integer | Hardcoded `2` (Approved) | Not sourced from SAC |
| 41 | — | — | `defined_by` | integer | Hardcoded `0` (Global) | Not sourced from SAC |
| 42 | `advance_joiners_date` | timestamp without time zone | `advance_joiners_date` | timestamp without time zone | Direct copy | From `vessel_details` |
| 43 | `cba_itf_type` | bigint | `is_itf` | boolean | ITF=1 → true; NON_ITF=2 → false; else false | NOT NULL; defaults to false |
| 44 | — | — | `is_ums` | boolean | Hardcoded `false` | UMS flag not in `vessel_details`; TODO: source from wage/cba tables |
| 45 | `mlc_company_id`, `ship_management_company_id` | bigint, bigint | `is_doc_and_mlc_same` | boolean | true when MLC NULL and DOC present, or when both IDs equal; else false | Derived comparison of DOC vs MLC company |
| 46 | `register_owner_id`, `bare_boat_owner_id` | bigint, uuid | `is_registered_owner_and_signing_entity_same` | boolean | true when `register_owner_id` matches `bare_boat_owner_id` via `bare_boat_owner_id_mapping`; else false | Compares bigint owner ID to UUID identifier lookup |

**SAC columns not migrated to `vessel_revisions`:** `union_code`, `ship_management_company_id`, `mlc_company_id`, `sma_signing_entity_id` — used only for derived flags or handled in related tables.

**SAC column migrated elsewhere:** `is_bank_account_present` — post-migration UPDATE to `vessel_revision_owners.audit_info` (Registered Owner type).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `flags`
- `port_of_registry`
- `public.flags`
- `vessel.port_of_registry`
- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Flag ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='flags'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE flag_id_mapping AS
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    tm.target_id AS new_id
FROM migration.table_mappings tm
JOIN dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags'
) AS f(
    id bigint,
    identifier uuid
) ON f.identifier::text = tm.source_id
WHERE tm.target_table = 'flags'
  AND tm.target_db = current_database()
UNION
SELECT DISTINCT
    f.id::bigint AS legacy_id,
    f.identifier::uuid AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.flags'
) AS f(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'flags'
      AND tm.target_db = current_database()
      AND tm.source_id = f.identifier::text
);
```

### 3. Port ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='port_of_registry'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE port_id_mapping AS
SELECT DISTINCT ON (legacy_port.id)
    legacy_port.id::bigint AS legacy_id,
    por_map.target_id AS new_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.ports'
) AS legacy_port(id bigint, identifier uuid)
JOIN migration.table_mappings por_map
    ON por_map.source_id = legacy_port.identifier::text
    AND por_map.target_table = 'port_of_registry'
    AND por_map.target_db = current_database()
ORDER BY legacy_port.id, por_map.target_id;
```

### 4. Class ID Mapping
**Output columns**: `legacy_class_id, new_class_id`
**migration.table_mappings**: `target_table='classes'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE class_id_mapping AS
SELECT
    source_id::bigint AS legacy_class_id,
    target_id AS new_class_id
FROM migration.table_mappings
WHERE target_table = 'classes'
  AND target_db = current_database()
UNION
SELECT DISTINCT
    vc.id::bigint AS legacy_class_id,
    vc.identifier::uuid AS new_class_id
FROM dblink('synergy_vessel',
    'SELECT id, identifier FROM public.vessel_classes'
) AS vc(
    id bigint,
    identifier uuid
)
WHERE NOT EXISTS (
    SELECT 1 FROM migration.table_mappings tm
    WHERE tm.target_table = 'classes'
      AND tm.target_db = current_database()
      AND tm.source_id::bigint = vc.id
);
```

### 5. Bare Boat Owner ID Mapping
**Output columns**: `owner_id, owner_identifier`
**migration.table_mappings**: `vessel_bare_boat_owner` → `owners`

```sql
CREATE TEMP TABLE bare_boat_owner_id_mapping AS
SELECT
    tm.source_id::bigint AS owner_id,
    tm.target_id::uuid AS owner_identifier
FROM migration.table_mappings tm
WHERE tm.source_table = 'vessel_bare_boat_owner'
  AND tm.target_table = 'owners'
  AND tm.target_db = current_database()
  AND tm.source_id IS NOT NULL
  AND tm.target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/vessel_revisions_migration.sql`

## Validation

- Run `05-validation/master/vessel_revisions_validation.sql` if available
- Run `06-rollback/master/vessel_revisions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
