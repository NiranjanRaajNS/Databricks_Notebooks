# Table Mapping: seafarer_ml_form_documents → seafarer_ml_forms

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_ml_form_documents
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_ml_forms
- **Source Script**: `04-migration-scripts/crewing/seafarer_ml_forms_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_ml_form_documents`
- **New Path**: `smac_crewing_migration.shore.seafarer_ml_forms`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer ML Form Documents (`seafarer_ml_form_documents` → `seafarer_ml_forms`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- Filter: `seafarer_id IN (SELECT uuid FROM public.seafarers)` in SAC dblink query
- `seafarer_id` mapped via `seafarers_id_mapping` on `target_id::text`; nil UUID if unmapped
- `ml_details_id` copied directly to `ml_forms_template_id` (uuid)
- `workflow_status_id` from APPROVED workflow status lookup; nil UUID fallback
- `mailed_to_seafarer` hardcoded `false`; `content` = `NULL`
- Uses `migration.build_audit_info()` with created/deleted/updated by fields
- Requires `seafarers` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_ml_forms` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `workflow_status_lookup` | APPROVED workflow status lookup | `status_code`, `workflow_status_id` | - | `smac_master_migration` |
| `seafarers_id_mapping` | FK lookup for `seafarer_id` | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `workflow_status_lookup`

- **Purpose**: APPROVED workflow status lookup
- **Output columns**: status_code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code = ''APPROVED'''
) AS ws(code text, id uuid);
```

### `seafarers_id_mapping`

- **Purpose**: FK lookup for `seafarer_id` (match on `target_id::text`)
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC `id` |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; nil UUID if unmapped | Only rows with valid seafarer mapping migrated |
| 3 | `ml_details_id` | uuid | `ml_forms_template_id` | uuid | Direct copy | SAC template reference preserved |
| 4 | — | — | `mailed_to_seafarer` | boolean | Hardcoded `false` | NOT NULL in SMAC; not in SAC source |
| 5 | — | — | `content` | text | `NULL` | No source content field |
| 6 | `generate_file_path` | text | `file_path` | text | `TRIM(generate_file_path)` | SAC file path |
| 7 | — | — | `workflow_status_id` | uuid | APPROVED from `workflow_status_lookup`; nil UUID fallback | Lookup: `public.workflow_status` via dblink |
| 8 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 9 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 10 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 14 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 15 | `created_by_id`, `deleted_by_id`, `updated_by_id`, names | text | `audit_info` | jsonb | `migration.build_audit_info()` — includes deleted_by |- |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `template_status`, `upload_file_path`, `creation_type`, `reference_id` — not referenced in INSERT; `deleted_by_name` — used only in `audit_info` via `build_audit_info`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Workflow Status ID Mapping
**Purpose**: APPROVED workflow status lookup
**Output columns**: `status_code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code = ''APPROVED'''
) AS ws(code text, id uuid);
```

### 2. Seafarers ID Mapping
**Purpose**: FK lookup for `seafarer_id` (match on `target_id::text`)
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_ml_forms_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_ml_forms_validation.sql` if available
- Run `06-rollback/crewing/seafarer_ml_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
