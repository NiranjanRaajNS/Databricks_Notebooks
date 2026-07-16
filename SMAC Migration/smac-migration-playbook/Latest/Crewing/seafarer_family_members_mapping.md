# Table Mapping: family_details → seafarer_family_members

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: family_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_family_members
- **Source Script**: `04-migration-scripts/crewing/seafarer_family_members_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.family_details`
- **New Path**: `smac_crewing_migration.public.seafarer_family_members`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Family Members (`family_details` → `seafarer_family_members`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `seafarer_id` mapped via `migration.table_mappings` (`seafarers`) — required; unmapped rows excluded
- `gender` (integer) → `gender_id` via `gender_id_mapping` (`genders`)
- `family_relation_id` → `relation_id` via `relation_id_mapping` (`family_relations`); empty GUID fallback
- `nationality_id` mapped via `nationality_id_mapping` (`nationalities`)
- Filter: `uuid IS NOT NULL OR id IS NOT NULL`; only rows with resolvable `seafarer_id`
- Pre-migration duplicate UUID check on SAC `uuid` column
- All records migrated including deleted (`deleted_at` preserved)

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_family_members` before insert (full table reload)
- Orchestration dependencies: `seafarers`, `family_relations`, `genders`, `nationalities`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relation_id_mapping` | FK lookup | `legacy_id::bigint`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `gender_id_mapping` | FK lookup | `legacy_id::integer`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `nationality_id_mapping` | FK lookup | `legacy_id::text`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `relation_id_mapping`

- **Output columns**: legacy_id::bigint, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE relation_id_mapping AS
SELECT legacy_id::bigint, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''family_relations'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### `gender_id_mapping`

- **Output columns**: legacy_id::integer, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT legacy_id::integer, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### `nationality_id_mapping`

- **Output columns**: legacy_id::text, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT legacy_id::text, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `migration.table_mappings` where `target_table = 'seafarers'` | Required — unmapped seafarers excluded |
| 3 | `first_name` | text | `first_name` | text | `TRIM(first_name)` | Direct copy with whitespace trimmed |
| 4 | — | — | `middle_name` | text | Hardcoded NULL | Not in SAC source |
| 5 | `last_name` | text | `last_name` | text | `TRIM(last_name)` | Direct copy with whitespace trimmed |
| 6 | `gender` | integer | `gender_id` | uuid | Map via `gender_id_mapping` on `gender` | Lookup: `migration.table_mappings` (`genders`) |
| 7 | `date_of_birth` | timestamp without time zone | `date_of_birth` | date | Cast `date_of_birth` to date | Type conversion timestamp → date |
| 8 | `nationality_id` | bigint | `nationality_id` | uuid | Map via `nationality_id_mapping` on `nationality_id::text` | Lookup: `migration.table_mappings` (`nationalities`) |
| 9 | `family_relation_id` | bigint | `relation_id` | uuid | Map via `relation_id_mapping`; empty GUID fallback | NOT NULL; lookup: `family_relations` |
| 10 | `is_dependent` | boolean | `is_dependent` | boolean | `COALESCE(is_dependent, false)` | Direct copy with default |
| 11 | `is_nok` | boolean | `is_next_of_kin` | boolean | `COALESCE(is_nok, false)` | SAC `is_nok` renamed to `is_next_of_kin` |
| 12 | `is_ice` | boolean | `is_emergency_contact` | boolean | `COALESCE(is_ice, false)` | SAC `is_ice` renamed to `is_emergency_contact` |
| 13 | — | — | `dependency_notes` | text | Hardcoded NULL | Not in SAC source |
| 14 | `passport_number` | text | `passport_number` | text | `TRIM(passport_number)` | Direct copy with whitespace trimmed |
| 15 | `date_of_issue` | timestamp without time zone | `passport_issue_date` | date | Cast `date_of_issue` to date | SAC `date_of_issue` renamed to `passport_issue_date` |
| 16 | `expiry_date` | timestamp without time zone | `passport_expiry_date` | date | Cast `expiry_date` to date | SAC `expiry_date` renamed to `passport_expiry_date` |
| 17 | `place_of_issue` | text | `passport_place_of_issue` | text | `TRIM(place_of_issue)` | SAC `place_of_issue` renamed to `passport_place_of_issue` |
| 18 | `contact` | text | `contact_number` | text | `TRIM(contact)` | SAC `contact` renamed to `contact_number` |
| 19 | — | — | `email` | text | Hardcoded NULL | Not in SAC source |
| 20 | `address` | text | `address` | text | `TRIM(address)` | Direct copy with whitespace trimmed |
| 21 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 22 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 23 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 24 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 25 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 26 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | SAC has no audit columns; standardized SMAC structure |

**SAC columns not migrated:** `relation`, `seafarer_uuid`, `insurance_id`, `supernumerary_code` — present in source but not inserted into SMAC.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `family_relations`
- `genders`
- `nationalities`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relation ID Mapping
**Output columns**: `legacy_id::bigint, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE relation_id_mapping AS
SELECT legacy_id::bigint, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''family_relations'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### 2. Gender ID Mapping
**Output columns**: `legacy_id::integer, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT legacy_id::integer, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''genders'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

### 3. Nationality ID Mapping
**Output columns**: `legacy_id::text, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE nationality_id_mapping AS
SELECT legacy_id::text, new_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''nationalities'' AND target_db = current_database()'
) AS t(legacy_id text, new_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_family_members_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_family_members_validation.sql` if available
- Run `06-rollback/crewing/seafarer_family_members_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
