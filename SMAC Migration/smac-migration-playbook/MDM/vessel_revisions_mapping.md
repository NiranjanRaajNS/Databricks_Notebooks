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

- Uses migration.resolve_target_id() to preserve legacy identifier (UUID) as id
- Maps vessel_id from vessel_details.vessel_id (bigint) to vessel.vessels.id (uuid)
- Maps flag_id from vessel_details.flag_id (bigint) to public.flags.id (uuid)
- Maps registered_port_id from vessel_details.port_id (bigint) to vessel.port_of_registry.id (uuid)
- Maps revision_status: ACTIVE→5, INACTIVE→7, ActivationPending→9 (PendingConfirmation), HandoverPending→3 (HandOverPending)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessels, flags, and port_of_registry to be migrated first
- Migrates vessel_details to vessel_revisions. Maps vessel_id from vessel_details.vessel_id (bigint) to vessel.vessels.id (uuid), flag_id from vessel_details.flag_id (bigint) to public.flags.id (uuid), and registered_port_id from vessel_details.port_id (bigint) to vessel.port_of_registry.id (uuid). Uses vessel_details.identifier (uuid) as id in target. Code is generated from vessel_code or imo_number. Requires vessels, flags, and port_of_registry tables to be migrated first.

## Special Considerations

- Rule 2.2.1 Case 2: deleted_at takes precedence over status
- Script performs `TRUNCATE TABLE vessel.vessel_revisions` before insert (full table reload).
- Orchestration dependencies: `vessels`, `flags`, `port_of_registry`

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
| 1 | identifier, id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details'::VARCHAR(100), COALESCE(vd.identifier::text, vd.id::text), current_database... |
| 2 | derived | - | vessel_id | - | vim.new_id AS vessel_id | vim.new_id |
| 3 | vessel_code, imo_number | - | code | - | COALESCE( NULLIF(TRIM(vd.vessel_code), ''), vd.imo_number::text ) AS code | COALESCE( NULLIF(TRIM(vd.vessel_code), ''), vd.imo_number::text ) |
| 4 | name | - | name | - | TRIM(vd.name) AS name | TRIM(vd.name) |
| 5 | mmsi | - | mmsi | - | CASE WHEN vd.mmsi IS NOT NULL THEN vd.mmsi::text ELSE NULL END AS mmsi | CASE WHEN vd.mmsi IS NOT NULL THEN vd.mmsi::text ELSE NULL END |
| 6 | call_sign | - | call_sign | - | CASE WHEN vd.call_sign IS NOT NULL AND TRIM(vd.call_sign) != '' THEN TRIM(vd.call_sign) ELSE NULL END AS call_sign | CASE WHEN vd.call_sign IS NOT NULL AND TRIM(vd.call_sign) != '' THEN TRIM(vd.call_sign) ELSE NULL END |
| 7 | - | - | insurance_pi_id | - | NULL | NULL::uuid |
| 8 | - | - | insurance_hm_id | - | NULL | NULL::uuid |
| 9 | takeover_date | - | takeover_on | - | vd.takeover_date AS takeover_on | vd.takeover_date |
| 10 | handover_date | - | handover_on | - | vd.handover_date AS handover_on | vd.handover_date |
| 11 | derived | - | flag_id | - | fim.new_id AS flag_id | fim.new_id |
| 12 | derived | - | registered_port_id | - | pim.new_id AS registered_port_id | pim.new_id |
| 13 | derived | - | class_id | - | cim.new_class_id AS class_id | cim.new_class_id |
| 14 | - | - | skin_friction_reduction | - | NULL | NULL::text |
| 15 | - | - | last_drydock | - | NULL | NULL::timestamp |
| 16 | - | - | silicone_paint_applied_on | - | NULL | NULL::timestamp |
| 17 | - | - | last_uw_coating_application | - | NULL | NULL::timestamp |
| 18 | - | - | surface_preparation | - | NULL | NULL::text |
| 19 | - | - | last_uw_inspection | - | NULL | NULL::timestamp |
| 20 | - | - | intended_next_coating_application | - | NULL | NULL::text |
| 21 | - | - | last_hull_cleaning | - | NULL | NULL::timestamp |
| 22 | - | - | uw_coating_paint | - | NULL | NULL::text |
| 23 | - | - | last_propeller_polishing | - | NULL | NULL::timestamp |
| 24 | - | - | uw_coating | - | NULL | NULL::text |
| 25 | official_number | - | official_number | - | CASE WHEN vd.official_number IS NOT NULL AND TRIM(vd.official_number) != '' THEN TRIM(vd.official_number) ELSE NULL END AS official_number | CASE WHEN vd.official_number IS NOT NULL AND TRIM(vd.official_number) != '' THEN TRIM(vd.official_number) ELSE NULL END |
| 26 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 27 | - | - | parent_id | - | NULL | NULL::uuid |
| 28 | derived | - | version | - | 1 AS version | 1 |
| 29 | created_at | - | created_at | - | COALESCE(vd.created_at, NOW()) AS created_at | COALESCE(vd.created_at, NOW()) |
| 30 | updated_at | - | updated_at | - | COALESCE(vd.updated_at, NOW()) AS updated_at | COALESCE(vd.updated_at, NOW()) |
| 31 | deleted_at | - | deleted_at | - | vd.deleted_at AS deleted_at | vd.deleted_at |
| 32 | - | - | archived_at | - | NULL | NULL::timestamp |
| 33 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 34 | name | - | level | - | (ROW_NUMBER() OVER (ORDER BY TRIM(vd.name)) - 1)::numeric AS level | (ROW_NUMBER() OVER (ORDER BY TRIM(vd.name)) - 1)::numeric |
| 35 | takeover_date | - | effective_date | - | vd.takeover_date AS effective_date | vd.takeover_date |
| 36 | - | - | parent_revision_id | - | NULL | NULL::uuid |
| 37 | status | - | revision_status | - | CASE WHEN UPPER(TRIM(vd.status)) = 'DRAFT' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' THEN 5 WHEN UPPER(TRIM(vd.status)) = 'INACTIVE' THEN 7 WHEN UPPER(TRIM(vd.status)) = 'AC... | CASE WHEN UPPER(TRIM(vd.status)) = 'DRAFT' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' THEN 5 WHEN UPPER(TRIM(vd.status)) = 'INACTIVE' THEN 7 WHEN UPPER(TRIM(vd.status)) = 'AC... |
| 38 | - | - | tags | - | NULL | NULL::text[] |
| 39 | deleted_at, status | - | status | - | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '1' THEN 0 WHEN UPPE... | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '1' THEN 0 WHEN UPPE... |
| 40 | derived | - | workflow_status | - | 2 AS workflow_status | 2 |
| 41 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 42 | advance_joiners_date | - | advance_joiners_date | - | vd.advance_joiners_date AS advance_joiners_date | vd.advance_joiners_date |
| 43 | cba_itf_type | - | is_itf | - | COALESCE( CASE WHEN vd.cba_itf_type = 1 THEN true WHEN vd.cba_itf_type = 2 THEN false ELSE false END, false ) AS is_itf | COALESCE( CASE WHEN vd.cba_itf_type = 1 THEN true WHEN vd.cba_itf_type = 2 THEN false ELSE false END, false ) |
| 44 | derived | - | is_ums | - | false AS is_ums | false |
| 45 | mlc_company_id, ship_management_company_id | - | is_doc_and_mlc_same | - | CASE WHEN vd.mlc_company_id IS NULL AND vd.ship_management_company_id IS NOT NULL THEN true WHEN vd.ship_management_company_id IS NOT NULL AND vd.mlc_company_id IS NOT NULL AND ... | CASE WHEN vd.mlc_company_id IS NULL AND vd.ship_management_company_id IS NOT NULL THEN true WHEN vd.ship_management_company_id IS NOT NULL AND vd.mlc_company_id IS NOT NULL AND ... |
| 46 | register_owner_id, bare_boat_owner_id | - | is_registered_owner_and_signing_entity_same | - | CASE WHEN vd.register_owner_id IS NOT NULL AND vd.bare_boat_owner_id IS NOT NULL AND EXISTS ( SELECT 1 FROM bare_boat_owner_id_mapping bbo WHERE bbo.owner_identifier = vd.bare_b... | CASE WHEN vd.register_owner_id IS NOT NULL AND vd.bare_boat_owner_id IS NOT NULL AND EXISTS ( SELECT 1 FROM bare_boat_owner_id_mapping bbo WHERE bbo.owner_identifier = vd.bare_b... |

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
