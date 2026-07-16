# Table Mapping: vessel_contact_cards → vessel_contacts

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_contact_cards
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_contacts
- **Source Script**: `04-migration-scripts/master/vessel_contacts_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_contact_cards`
- **New Path**: `smac_master_migration.vessel.vessel_contacts`

## Business Key

- **Composite Key**: (`vessel_id`, `identifier`)
- **Source (orchestration)**: Vessel Contact Cards (`vessel_contact_cards` → `vessel_contacts`)

## Migration Notes

- Preserves identifier UUID as id (Pattern 4: identifier preserved as target id)
- Maps vessel_id from vessel_contact_cards.vessel_id (bigint) → migration.table_mappings.source_id (vessels) → vessel.vessels.id (uuid)
- Maps vessel_revision_id from active vessel_revisions (most recent by created_at)
- Maps country codes separately for each phone type
- Maps status (varchar) to status (integer): Active=0, Draft=1, Inactive=2, Deleted=3
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessels and vessel.vessel_revisions to be migrated first
- Migrates vessel_contact_cards to vessel_contacts. Preserves identifier UUID as id (Pattern 4: identifier preserved as target id). Maps vessel_id from vessel_contact_cards.vessel_id (bigint) → migration.table_mappings.source_id (vessels) → vessel.vessels.id (uuid). Maps vessel_revision_id from active vessel_revisions (most recent by created_at). Consolidates multiple phone fields: vsat_phone1-3 → phone_vsat jsonb, satc_number1-2 → satc_number jsonb. Maps country codes separately for each phone type. Maps status (varchar) to status (integer): Active=0, Draft=1, Inactive=2, Deleted=3. Requires vessel.vessels and vessel.vessel_revisions to be migrated first.

## Special Considerations

- Consolidates multiple phone fields: vsat_phone1-3 → phone_vsat jsonb, satc_number1-2 → satc_number (comma-separated string)
- Script performs `TRUNCATE TABLE vessel.vessel_contacts` before insert (full table reload).
- Orchestration dependencies: `vessels`, `vessel_revisions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    svcc.vessel_id AS vessel_details_id,
    v_mapping.target_id::uuid AS new_vessel_id
FROM staging_vessel_contact_cards svcc
LEFT JOIN dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
    ON vd.id = svcc.vessel_id
LEFT JOIN migration.table_mappings v_mapping
    ON v_mapping.source_id = vd.vessel_id::text
    AND v_mapping.target_table = 'vessels'
    AND v_mapping.target_db = current_database();
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
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_contact_cards'::VARCHAR(100), svcc.identifier::text, current_database()::text::VARCH... |
| 2 | derived | - | vessel_id | - | vim.new_vessel_id AS vessel_id | vim.new_vessel_id |
| 3 | derived | - | vessel_revision_id | - | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_revision_id | COALESCE(vrm.active_revision_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | derived | - | smt_mail_distribution_id | - | NULLIF(TRIM(svcc.smt_mail_distribution_id), '') AS smt_mail_distribution_id | NULLIF(TRIM(svcc.smt_mail_distribution_id), '') |
| 5 | derived | - | email | - | NULLIF(TRIM(svcc.email), '') AS email | NULLIF(TRIM(svcc.email), '') |
| 6 | derived | - | phone_fbb | - | NULLIF(TRIM(svcc.fbb_phone), '') AS phone_fbb | NULLIF(TRIM(svcc.fbb_phone), '') |
| 7 | derived | - | phone_fbb_country_code | - | NULLIF(TRIM(svcc.fbb_phone_countryinfo), '') AS phone_fbb_country_code | NULLIF(TRIM(svcc.fbb_phone_countryinfo), '') |
| 8 | - | - | phone_vsat | - | COALESCE( ( SELECT jsonb_agg(phone_obj ORDER BY phone_order) FROM ( SELECT 1 AS phone_order, jsonb_build_object('phone', TRIM(svcc.vsat_phone1), 'country_code', NULLIF(TRIM(svcc... | COALESCE( ( SELECT jsonb_agg(phone_obj ORDER BY phone_order) FROM ( SELECT 1 AS phone_order, jsonb_build_object('phone', TRIM(svcc.vsat_phone1), 'country_code', NULLIF(TRIM(svcc... |
| 9 | derived | - | phone_iridium | - | NULLIF(TRIM(svcc.iridium_phone), '') AS phone_iridium | NULLIF(TRIM(svcc.iridium_phone), '') |
| 10 | derived | - | phone_iridium_country_code | - | NULLIF(TRIM(svcc.iridium_phone_countryinfo), '') AS phone_iridium_country_code | NULLIF(TRIM(svcc.iridium_phone_countryinfo), '') |
| 11 | derived | - | mobile | - | NULLIF(TRIM(svcc.ship_mobile_number), '') AS mobile | NULLIF(TRIM(svcc.ship_mobile_number), '') |
| 12 | derived | - | mobile_country_code | - | NULLIF(TRIM(svcc.ship_mobile_number_countryinfo), '') AS mobile_country_code | NULLIF(TRIM(svcc.ship_mobile_number_countryinfo), '') |
| 13 | derived | - | mobile_master | - | NULLIF(TRIM(svcc.master_mobile_number), '') AS mobile_master | NULLIF(TRIM(svcc.master_mobile_number), '') |
| 14 | derived | - | mobile_master_country_code | - | NULLIF(TRIM(svcc.master_mobile_number_countryinfo), '') AS mobile_master_country_code | NULLIF(TRIM(svcc.master_mobile_number_countryinfo), '') |
| 15 | derived | - | fax | - | NULLIF(TRIM(svcc.fax), '') AS fax | NULLIF(TRIM(svcc.fax), '') |
| 16 | derived | - | fax_country_code | - | NULLIF(TRIM(svcc.fax_countryinfo), '') AS fax_country_code | NULLIF(TRIM(svcc.fax_countryinfo), '') |
| 17 | derived | - | telex | - | NULLIF(TRIM(svcc.telex), '') AS telex | NULLIF(TRIM(svcc.telex), '') |
| 18 | derived | - | nbdp | - | NULLIF(TRIM(svcc.nbdp), '') AS nbdp | NULLIF(TRIM(svcc.nbdp), '') |
| 19 | - | - | satc_number | - | CASE WHEN svcc.satc_number1 IS NOT NULL AND TRIM(svcc.satc_number1) <> '' AND svcc.satc_number2 IS NOT NULL AND TRIM(svcc.satc_number2) <> '' THEN to_jsonb(TRIM(svcc.satc_number... | CASE WHEN svcc.satc_number1 IS NOT NULL AND TRIM(svcc.satc_number1) <> '' AND svcc.satc_number2 IS NOT NULL AND TRIM(svcc.satc_number2) <> '' THEN to_jsonb(TRIM(svcc.satc_number... |
| 20 | derived | - | commercial_operator | - | NULLIF(TRIM(svcc.commercial_operator), '') AS commercial_operator | NULLIF(TRIM(svcc.commercial_operator), '') |
| 21 | derived | - | image_info | - | CASE WHEN svcc.vessel_image_file_id IS NOT NULL AND TRIM(svcc.vessel_image_file_id) <> '' THEN jsonb_build_object('file_id', TRIM(svcc.vessel_image_file_id)) ELSE NULL END AS im... | CASE WHEN svcc.vessel_image_file_id IS NOT NULL AND TRIM(svcc.vessel_image_file_id) <> '' THEN jsonb_build_object('file_id', TRIM(svcc.vessel_image_file_id)) ELSE NULL END |
| 22 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 23 | - | - | parent_id | - | NULL | NULL::uuid |
| 24 | derived | - | version | - | 1 AS version | 1 |
| 25 | derived | - | created_at | - | COALESCE(svcc.created_at, NOW()) AS created_at | COALESCE(svcc.created_at, NOW()) |
| 26 | derived | - | updated_at | - | COALESCE(svcc.updated_at, NOW()) AS updated_at | COALESCE(svcc.updated_at, NOW()) |
| 27 | derived | - | deleted_at | - | svcc.deleted_at AS deleted_at | svcc.deleted_at |
| 28 | - | - | archived_at | - | NULL | NULL::timestamp |
| 29 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 30 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 31 | - | - | tags | - | NULL | NULL::text[] |
| 32 | - | - | status | - | STATUS_DELETED | CASE WHEN svcc.deleted_at IS NOT NULL THEN :'STATUS_DELETED'::integer WHEN UPPER(TRIM(COALESCE(svcc.status, ''))) = 'ACTIVE' THEN :'STATUS_ACTIVE'::integer WHEN UPPER(TRIM(COALE... |
| 33 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 34 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.vessels`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    svcc.vessel_id AS vessel_details_id,
    v_mapping.target_id::uuid AS new_vessel_id
FROM staging_vessel_contact_cards svcc
LEFT JOIN dblink('synergy_vessel',
    'SELECT id, identifier, vessel_id
     FROM public.vessel_details
     WHERE identifier IS NOT NULL AND vessel_id IS NOT NULL'
) AS vd(id bigint, identifier uuid, vessel_id bigint)
    ON vd.id = svcc.vessel_id
LEFT JOIN migration.table_mappings v_mapping
    ON v_mapping.source_id = vd.vessel_id::text
    AND v_mapping.target_table = 'vessels'
    AND v_mapping.target_db = current_database();
```

### 2. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/master/vessel_contacts_migration.sql`

## Validation

- Run `05-validation/master/vessel_contacts_validation.sql` if available
- Run `06-rollback/master/vessel_contacts_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
