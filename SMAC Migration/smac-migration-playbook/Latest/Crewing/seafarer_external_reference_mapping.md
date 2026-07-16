# Table Mapping: seafarer_external_reference → seafarer_external_reference

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarers
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: external_references
- **Source Script**: `04-migration-scripts/crewing/seafarer_external_reference_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarers` (filtered: `sap_bp_number` populated)
- **New Path**: `smac_crewing_migration.shore.external_references`


## Business Key

- **Composite Key**: (`entity_type`, `entity_id`, `source_reference_no`, `source_system_id`)
- **Source (orchestration)**: Seafarer SAP BP External References (`seafarers` → `external_references`)

## Migration Notes

- Derives rows from SAC `seafarers` where `sap_bp_number` is not null/empty — one external reference per seafarer
- Source `id` is bigint (seafarer id), target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL`
- `entity_id` = SAC `uuid` (preserved seafarer UUID in SMAC)
- `source_system_id` hardcoded `'aa84561c-960c-490e-aef2-157c594ac43a'` (SAP system UUID; no `constants.sql` entry)
- `reference_type` hardcoded `'sap_bp_number'`; `entity_type` hardcoded `'seafarers'`
- `status` hardcoded `'Active'` for all migrated rows
- `audit_info` set to `NULL` (not populated for SAP BP linkage rows)
- `deleted_at` preserved from SAC `seafarers.deleted_at`
- `INNER JOIN seafarers_id_mapping` — only seafarers already migrated to SMAC are included
- Idempotent slice: prior SAP BP rows deleted before INSERT; `resolve_target_id` reuses UUID on repeated migration
- Requires `public.seafarers` migrated first (`table_mappings` where `target_table = 'seafarers'`)

## Special Considerations

- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | - migration.resolve_target_id() for id (reuse UUID when mappings exist for | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Purpose**: - migration.resolve_target_id() for id (reuse UUID when mappings exist for
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT source_id::text AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = seafarer `id::text`; `p_target_id = NULL` | Idempotent UUID; source is SAC `seafarers.id` |
| 2 | — | — | `entity_type` | text | Hardcoded `'seafarers'` | SMAC polymorphic entity type |
| 3 | `uuid` | uuid | `entity_id` | uuid | `uuid::uuid` | SAC seafarer UUID preserved as entity reference |
| 4 | — | — | `source_system_id` | uuid | Hardcoded `'aa84561c-960c-490e-aef2-157c594ac43a'` | SAP system identifier (fixed UUID) |
| 5 | `sap_bp_number` | text | `source_reference_no` | text | `TRIM(sap_bp_number)` | SAP business partner number |
| 6 | — | — | `reference_type` | text | Hardcoded `'sap_bp_number'` | Reference type discriminator |
| 7 | — | — | `status` | character varying(50) | Hardcoded `'Active'` | All migrated SAP BP rows set to Active |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From SAC `seafarers.created_at` |
| 10 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 11 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete from SAC `seafarers` preserved |
| 13 | — | — | `audit_info` | jsonb | `NULL` | Intentionally not populated for SAP BP linkage rows |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** All other `seafarers` columns — only `id`, `uuid`, `sap_bp_number`, `created_at`, `updated_at`, `deleted_at` used. Filter: `sap_bp_number IS NOT NULL AND TRIM(sap_bp_number) <> ''`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: - migration.resolve_target_id() for id (reuse UUID when mappings exist for
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT source_id::text AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_external_reference_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_external_reference_validation.sql` if available
- Run `06-rollback/crewing/seafarer_external_reference_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
