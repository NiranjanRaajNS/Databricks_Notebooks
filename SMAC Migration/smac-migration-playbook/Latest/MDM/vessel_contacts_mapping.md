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

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on SAC `identifier` column
- `vessel_id` via `vessel_details` → vessels mapping; `vessel_revision_id` from active revision
- VSAT phones consolidated into `phone_vsat` JSONB array; SAT-C numbers into `satc_number` JSONB
- `status` Case 2: `deleted_at` takes precedence over `status` string
- `image_info` JSONB from `vessel_image_file_id`
- Migrate ALL records including deleted
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
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC uuid as SMAC id |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` through `vessel_details` | FK lookup |
| 3 | `—` | — | `vessel_revision_id` | uuid | Active revision or placeholder UUID | FK lookup |
| 4 | `smt_mail_distribution_id` | character varying | `smt_mail_distribution_id` | character varying | `NULLIF(TRIM(smt_mail_distribution_id), '')` | Direct copy |
| 5 | `email` | character varying | `email` | character varying | `TRIM(email)` | Direct copy |
| 6 | `fbb_phone` | character varying | `phone_fbb` | character varying | `TRIM(fbb_phone)` | Direct copy |
| 7 | `fbb_phone_countryinfo` | character varying | `phone_fbb_country_code` | character varying | `TRIM(fbb_phone_countryinfo)` | Country code |
| 8 | `vsat_phone1, vsat_phone2, vsat_phone3, *_countryinfo` | character varying | `phone_vsat` | jsonb | `jsonb_agg` of `{phone, country_code}` objects | Consolidated VSAT phones |
| 9 | `iridium_phone` | character varying | `phone_iridium` | character varying | `TRIM(iridium_phone)` | Direct copy |
| 10 | `iridium_phone_countryinfo` | character varying | `phone_iridium_country_code` | character varying | `TRIM(iridium_phone_countryinfo)` | Country code |
| 11 | `ship_mobile_number` | character varying | `mobile` | character varying | `TRIM(ship_mobile_number)` | Direct copy |
| 12 | `ship_mobile_number_countryinfo` | character varying | `mobile_country_code` | character varying | `TRIM(ship_mobile_number_countryinfo)` | Country code |
| 13 | `master_mobile_number` | character varying | `mobile_master` | character varying | `TRIM(master_mobile_number)` | Direct copy |
| 14 | `master_mobile_number_countryinfo` | character varying | `mobile_master_country_code` | character varying | `TRIM(master_mobile_number_countryinfo)` | Country code |
| 15 | `fax` | character varying | `fax` | character varying | `TRIM(fax)` | Direct copy |
| 16 | `fax_countryinfo` | character varying | `fax_country_code` | character varying | `TRIM(fax_countryinfo)` | Country code |
| 17 | `telex` | character varying | `telex` | character varying | `TRIM(telex)` | Direct copy |
| 18 | `nbdp` | character varying | `nbdp` | character varying | `TRIM(nbdp)` | Direct copy |
| 19 | `satc_number1, satc_number2` | character varying | `satc_number` | jsonb | Comma-joined values → `to_jsonb()` | Consolidated SAT-C |
| 20 | `commercial_operator` | character varying | `commercial_operator` | character varying | `TRIM(commercial_operator)` | Direct copy |
| 21 | `vessel_image_file_id` | text | `image_info` | jsonb | `jsonb_build_object('file_id', vessel_image_file_id)` | File reference JSON |
| 22 | `status, deleted_at` | character varying, timestamp without time zone | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Case 2 |
| 23 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 24 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 25 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 26 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 27 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 28 | `—` | — | `level` | integer | Hardcoded `0` | Default hierarchy level |
| 29 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 30 | `—` | — | `tags` | text[] | `NULL` | Not populated |
| 31 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 32 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 33 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 34 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | Source `audit_info` replaced |

**SAC columns not migrated:** Source `audit_info` JSONB — replaced with standardized SMAC audit.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.vessels`
- `vessel_revisions`
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
