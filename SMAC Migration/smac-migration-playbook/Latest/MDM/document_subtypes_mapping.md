# Table Mapping: document_subtypes → document_subtypes

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: document
- **Legacy Table**: document_subtypes
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: document_subtypes
- **Source Script**: `04-migration-scripts/master/document_subtypes_migration.sql`

- **Legacy Path**: `synergy_master.document.document_subtypes`
- **New Path**: `smac_master_migration.document.document_subtypes`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Subtypes (`document_subtypes` → `document_subtypes`)

## Migration Notes

- Source: `synergy_master.document.document_subtypes`
- SAC `id` preserved; `document_type_id` via `document_type_id_mapping`
- Pre-migration duplicate UUID check on SAC `id`
- Requires `document_types` migrated first


## Special Considerations

- Requires document_types table to be migrated first (for document_type_id mapping)
- Script performs `TRUNCATE TABLE document.document_subtypes` before insert (full table reload).
- Orchestration dependencies: `document_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `document_type_id_mapping` | Check for duplicate UUIDs in source table | `source_id::text`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `document_type_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: source_id::text, target_id
- **migration.table_mappings**: target_table=document_types

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | UUID preserved |
| 2 | `name` | text | `name` | text | `TRIM(name)` | NOT NULL in SMAC |
| 3 | `code`, `name` | text | `code` | text | `COALESCE(NULLIF(TRIM(code), ''), LEFT(TRIM(name), 10))` | |
| 4 | `document_type_id` | uuid | `document_type_id` | uuid | Map via `document_type_id_mapping`; fallback first document_type | FK: `document_types` |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 6 | — | — | `version` | integer | Hardcoded `1` | |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 9 | `status` | text | `status` | integer | Map status text/numeric to integer | |
| 10 | — | — | `level` | numeric | Hardcoded `0` | |
| 11 | `audit_info` | jsonb | `created_at` | timestamp without time zone | Extract `CreatedAt`; fallback `NOW()` | |
| 12 | `audit_info` | jsonb | `updated_at` | timestamp without time zone | Extract `UpdatedAt`; fallback `NOW()` | |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- `document.document_types`
- `document_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Document Type ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `source_id::text, target_id`
**migration.table_mappings**: `target_table='document_types'`

```sql
CREATE TEMP TABLE document_type_id_mapping AS
SELECT
    source_id::text,
    target_id
FROM migration.table_mappings
WHERE target_table = 'document_types'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/document_subtypes_migration.sql`

## Validation

- Run `05-validation/master/document_subtypes_validation.sql` if available
- Run `06-rollback/master/document_subtypes_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
