# Table Mapping: insurances → insurances

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: insurances
- **Source Script**: `04-migration-scripts/master/insurances_migration.sql`

- **Legacy Path**: `synergy_vessel.public.insurance_p_and_i + synergy_vessel.public.insurance_h_m`
- **New Path**: `smac_master_migration.vessel.insurances`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Insurance P And I,insurance H M (`insurance_p_and_i,insurance_h_m` → `insurances`)

## Migration Notes

- Sources: `synergy_vessel.public.insurance_p_and_i` + `insurance_h_m` → `vessel.insurances`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Duplicate UUID checks commented out in script
- `countries_id_mapping` FK lookup for `country_id`
- `type` discriminator: 0 = P&I, 1 = H&M
- TRUNCATE target; UNION ALL of both source tables
- `status` Case 2 from `deleted_at` + `status` text
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.insurances` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `countries_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `countries_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `identifier::text`; `p_target_id = identifier` | Per source table |
| 2 | `short_name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(short_name), identifier::text)` | NOT NULL |
| 3 | `full_name, identifier` | text, uuid | `name` | text | `COALESCE(TRIM(full_name), 'INS_P_AND_I_' / 'INS_H_M_' || suffix)` | NOT NULL |
| 4 | `—` | — | `description` | text | `NULL` |  |
| 5 | `address` | text | `address` | jsonb | `jsonb_build_object('full_address', TRIM(address))` when not NULL |  |
| 6 | `country_id` | uuid | `country_id` | uuid | Map via `countries_id_mapping` | FK lookup |
| 7 | `—` | — | `type` | integer | Hardcoded `0` (P&I) or `1` (H&M) by source table | Discriminator |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 12 | `deleted_at, status` | timestamp, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 13 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 14 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 15 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` |  |
| 16 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 17 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** None beyond defaults.",
)

# --- issuing_authorities ---
set_update(
    "issuing_authorities",
    [
        "- Source: distinct `issuing_authority` from `synergy_seafarer.document.seafarer_documents` → `document.issuing_authorities`",
        "- No SAC UUID column; `resolve_target_id()` with `p_target_id = NULL`",
        "- `staging_issuing_authorities` matches `place_of_issue` → `public.states.name` for `country_id`",
        "- `default_country` fallback when no state match",
        "- Filter: `issuing_authority` not null/empty/`-`",
        "- TRUNCATE target; `status` hardcoded Active (0)",
        "- `created_at`/`updated_at` set to `NOW()`",
    ],
    [
        row(1, "issuing_authority", "text", "id", "uuid", "`migration.resolve_target_id()` — source_id = `InitCap(TRIM(issuing_authority))` truncated to 100; `p_target_id = NULL`", "Idempotent text key
## Foreign Key Dependencies

### Prerequisites (from source script)

- `countries`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Countries ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE countries_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'countries'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/insurances_migration.sql`

## Validation

- Run `05-validation/master/insurances_validation.sql` if available
- Run `06-rollback/master/insurances_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
