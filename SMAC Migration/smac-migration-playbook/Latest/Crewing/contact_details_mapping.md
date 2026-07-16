# Table Mapping: contact_details → contact_details

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: contact_details
- **New Database**: smac_crewing_migration
- **New Schema**: shared
- **New Table**: contact_details
- **Source Script**: `04-migration-scripts/crewing/contact_details_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.contact_details`
- **New Path**: `smac_crewing_migration.shared.contact_details`


## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Contact Details (`contact_details` → `contact_details`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id`; generates new UUID when `uuid` is NULL or zero UUID
- `seafarer_id` mapped via `seafarer_id_mapping`; default nil UUID when unmapped (NOT NULL constraint)
- Address fields combined into `address` JSONB (`address_line`, `city`, `state_id`, `country_id`, `pin_code`, `country_code`)
- `phone` → `phone_number`; `emergency_contact_number` → `alternate_phone_number`; `emergency_contact_person` → `full_name`
- `is_active` hardcoded `true`; `preferred_contact` hardcoded `false`
- Filter: only rows where `deleted_at IS NULL` are migrated
- Mappings stored via `migration.store_table_mappings()` after INSERT
- Requires `seafarers` table migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shared.contact_details` before insert (full table reload)
- Orchestration dependencies: `seafarers`
- `audit_info` includes `legacy_id` (SAC bigint `id`) for records without preserved UUID

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 2 | `uuid`, `id` | uuid, bigint | `id` | uuid | Preserve `uuid`; `gen_random_uuid()` when NULL or zero UUID | SAC `uuid` used directly as SMAC `id` when valid |
| 3 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; default nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarers'`; NOT NULL in SMAC |
| 4 | `contact_type` | integer | `contact_type` | integer | `COALESCE(contact_type, 0)` | Default 0 when NULL; NOT NULL in SMAC |
| 5 | `emergency_contact_person` | character varying | `full_name` | text | `TRIM(emergency_contact_person)` when non-empty; else NULL | SAC emergency contact person renamed to `full_name` |
| 6 | — | — | `relationship_to_seafarer` | character varying | `NULL` | No equivalent in SAC; not populated |
| 7 | `email` | character varying | `email` | text | `TRIM(email)` when non-empty; else NULL | Direct copy with trim |
| 8 | `phone` | character varying | `phone_number` | text | `TRIM(phone)` when non-empty; else NULL | SAC `phone` renamed to `phone_number` |
| 9 | `emergency_contact_number` | character varying | `alternate_phone_number` | text | `TRIM(emergency_contact_number)` when non-empty; else NULL | SAC emergency number mapped to alternate phone |
| 10 | `address`, `city`, `state_id`, `country_id`, `pin_code`, `country_code` | character varying, bigint | `address` | jsonb | `jsonb_build_object` with `address_line`, `city`, `state_id`, `country_id`, `pin_code`, `country_code` | Combined into JSONB when any field present; else NULL |
| 11 | — | — | `preferred_contact` | boolean | Hardcoded `false` | Not in SAC source; NOT NULL in SMAC |
| 12 | — | — | `is_active` | boolean | Hardcoded `true` | Not in SAC source; NOT NULL in SMAC |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 16 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Always NULL for migrated rows | Source query filters `WHERE deleted_at IS NULL` — deleted SAC records are excluded |
| 17 | `created_by_id`, `updated_by_id`, `id` | character varying, bigint | `audit_info` | jsonb | Standard SMAC `jsonb_build_object` structure; includes `legacy_id` = SAC `id::text` | Uses `legacy_id` in audit_info for mapping when UUID not preserved |

**SAC columns not migrated:** `nearest_airport`, `fax`, `user_id`, `created_by_name`, `updated_by_name` — selected in dblink but not mapped to SMAC columns.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/contact_details_migration.sql`

## Validation

- Run `05-validation/crewing/contact_details_validation.sql` if available
- Run `06-rollback/crewing/contact_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
