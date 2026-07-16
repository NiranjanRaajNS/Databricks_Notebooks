# Table Mapping: seafarer_profile_status_histories → seafarer_profile_status_histories

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_profile_status_histories
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_profile_status_histories
- **Source Script**: `04-migration-scripts/crewing/seafarer_profile_status_histories_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_profile_status_histories`
- **New Path**: `smac_crewing_migration.public.seafarer_profile_status_histories`

## Business Key

- **Composite Key**: (`seafarer_id`, `status`, `changed_at`)
- **Source (orchestration)**: Seafarer Profile Status Histories (`seafarer_profile_status_histories` → `seafarer_profile_status_histories`, group: SeafarerProfile)

## Migration Notes

- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL`
- `seafarer_id` via `seafarers_id_mapping`; nil UUID if unmapped
- `new_status_id`: SAC `status` 1 → Active UUID, 0 → InActive UUID (via `seafarer_profile_statuses_mapping`)
- `old_status_id`: opposite of `new_status_id` (Active ↔ InActive inference)
- `reason_id`: from `seafarer_remarks.profile_remark` → `profile_remark_reasons` via remark_identifier
- `remarks`: aggregated remark text from `seafarer_remarks_for_reason_mapping`
- `workflow_status_id` from APPROVED workflow status lookup
- `status` (text): integer SAC status mapped to Active/Draft/Inactive/Deleted text values
- `archived_at`, `deleted_at` = `NULL` (not in SAC)
- Requires `seafarers` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_profile_status_histories` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_profile_statuses_mapping` | FK lookup | `status_name`, `status_id` | - | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `profile_remark_reason_mappings_from_master` | FK lookup | `source_id`, `target_id` | `?.?.seafarer_profile_remarks` → `?.?.profile_remark_reasons` | `smac_master_migration` |
| `profile_remark_reason_mapping` | FK lookup | `source_id`, `reason_name`, `target_id` | - | `synergy_seafarer` |
| `seafarer_remarks_for_reason_mapping` | FK lookup | `DISTINCT ON (sr.seafarer_id) sr.seafarer_id`, `remark_identifier`, `remarks_text` | - | `synergy_seafarer` |

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

### `seafarer_profile_statuses_mapping`

- **Output columns**: status_name, status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_profile_statuses_mapping AS
SELECT
    sps.name as status_name,
    sps.id as status_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_profile_statuses WHERE name IN (''Active'', ''InActive'')'
) AS sps(id uuid, name text)
WHERE sps.name IS NOT NULL;
```

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `profile_remark_reason_mappings_from_master`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_table=seafarer_profile_remarks, target_table=profile_remark_reasons
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings_from_master AS
SELECT source_id, target_id
FROM dblink('smac_master_migration',
    $query$SELECT source_id, target_id FROM migration.table_mappings
           WHERE target_table = 'profile_remark_reasons'
             AND source_table = 'seafarer_profile_remarks'$query$
) AS tm(source_id text, target_id uuid);
```

### `profile_remark_reason_mapping`

- **Output columns**: source_id, reason_name, target_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE profile_remark_reason_mapping AS
SELECT
    spr.id::text AS source_id,
    spr.name AS reason_name,
    tm.target_id AS target_id
FROM dblink('synergy_seafarer',
    'SELECT id, name FROM public.seafarer_profile_remarks'
) AS spr(id bigint, name text)
LEFT JOIN profile_remark_reason_mappings_from_master tm ON
    tm.source_id = spr.id::text;
```

### `seafarer_remarks_for_reason_mapping`

- **Output columns**: DISTINCT ON (sr.seafarer_id) sr.seafarer_id, remark_identifier, remarks_text
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_remarks_for_reason_mapping AS
SELECT DISTINCT ON (sr.seafarer_id)
    sr.seafarer_id,
    (first_elem->>'remark_identifier')::text as remark_identifier,

    (SELECT STRING_AGG(TRIM(COALESCE(elem->>'remark', '')), '; ' ORDER BY (elem->>'remark_identifier')::text)
     FROM jsonb_array_elements(sr.profile_remark) AS elem
     WHERE elem->>'remark' IS NOT NULL AND TRIM(elem->>'remark') != ''
    ) as remarks_text
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, profile_remark FROM public.seafarer_remarks WHERE profile_remark IS NOT NULL AND jsonb_typeof(profile_remark) = ''array'''
) AS sr(seafarer_id bigint, profile_remark jsonb)
CROSS JOIN LATERAL jsonb_array_elements(sr.profile_remark) AS first_elem
WHERE first_elem->>'remark_identifier' IS NOT NULL
ORDER BY sr.seafarer_id, (first_elem->>'remark_identifier')::text;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; SAC has bigint `id` only |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` where `target_table = 'seafarers'` |
| 3 | `status` | integer | `old_status_id` | uuid | SAC 1 (Active) → InActive UUID; SAC 0 → Active UUID | Opposite-of-current inference |
| 4 | `status` | integer | `new_status_id` | uuid | SAC 1 → Active UUID; SAC 0 → InActive UUID; nil UUID fallback | Lookup: `seafarer_profile_statuses` by name |
| 5 | `seafarer_remarks` (join) | jsonb | `reason_id` | uuid | Map `remark_identifier` → `profile_remark_reasons` | Via `profile_remark_reason_mapping` |
| 6 | — | — | `source` | text | `NULL` | No equivalent in SAC; not populated |
| 7 | `seafarer_remarks` (join) | jsonb | `remarks` | text | `COALESCE(srrfm.remarks_text, NULL)` | Aggregated remark texts from profile_remark array |
| 8 | — | — | `workflow_status_id` | uuid | APPROVED from `workflow_status_id_mapping`; nil UUID fallback | Lookup via dblink `smac_master_migration` |
| 9 | — | — | `is_verified` | boolean | Hardcoded `false` | NOT NULL in SMAC; not in SAC source |
| 10 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 11 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 12 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC; not populated |
| 13 | `status` | integer | `status` | text | NULL→Active; 0→Active; 1→Draft; 2→Inactive; 3→Deleted; else `status::text` | Integer to text conversion |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 16 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 17 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 18 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 19 | `created_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` — created_by only | - |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `created_by_name` — not referenced in migration INSERT.

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

### 2. Seafarer Profile Statuses ID Mapping
**Output columns**: `status_name, status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_profile_statuses_mapping AS
SELECT
    sps.name as status_name,
    sps.id as status_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_profile_statuses WHERE name IN (''Active'', ''InActive'')'
) AS sps(id uuid, name text)
WHERE sps.name IS NOT NULL;
```

### 3. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 4. Profile Remark Reason Mappings From Master ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `seafarer_profile_remarks` → `profile_remark_reasons`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings_from_master AS
SELECT source_id, target_id
FROM dblink('smac_master_migration',
    $query$SELECT source_id, target_id FROM migration.table_mappings
           WHERE target_table = 'profile_remark_reasons'
             AND source_table = 'seafarer_profile_remarks'$query$
) AS tm(source_id text, target_id uuid);
```

### 5. Profile Remark Reason ID Mapping
**Output columns**: `source_id, reason_name, target_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE profile_remark_reason_mapping AS
SELECT
    spr.id::text AS source_id,
    spr.name AS reason_name,
    tm.target_id AS target_id
FROM dblink('synergy_seafarer',
    'SELECT id, name FROM public.seafarer_profile_remarks'
) AS spr(id bigint, name text)
LEFT JOIN profile_remark_reason_mappings_from_master tm ON
    tm.source_id = spr.id::text;
```

### 6. Seafarer Remarks For Reason ID Mapping
**Output columns**: `DISTINCT ON (sr.seafarer_id) sr.seafarer_id, remark_identifier, remarks_text`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_remarks_for_reason_mapping AS
SELECT DISTINCT ON (sr.seafarer_id)
    sr.seafarer_id,
    (first_elem->>'remark_identifier')::text as remark_identifier,

    (SELECT STRING_AGG(TRIM(COALESCE(elem->>'remark', '')), '; ' ORDER BY (elem->>'remark_identifier')::text)
     FROM jsonb_array_elements(sr.profile_remark) AS elem
     WHERE elem->>'remark' IS NOT NULL AND TRIM(elem->>'remark') != ''
    ) as remarks_text
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, profile_remark FROM public.seafarer_remarks WHERE profile_remark IS NOT NULL AND jsonb_typeof(profile_remark) = ''array'''
) AS sr(seafarer_id bigint, profile_remark jsonb)
CROSS JOIN LATERAL jsonb_array_elements(sr.profile_remark) AS first_elem
WHERE first_elem->>'remark_identifier' IS NOT NULL
ORDER BY sr.seafarer_id, (first_elem->>'remark_identifier')::text;
```

Full migration context: `04-migration-scripts/crewing/seafarer_profile_status_histories_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_profile_status_histories_validation.sql` if available
- Run `06-rollback/crewing/seafarer_profile_status_histories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
