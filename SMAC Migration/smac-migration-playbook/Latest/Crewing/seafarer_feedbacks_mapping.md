# Table Mapping: feedback_comments → seafarer_feedbacks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: feedback_comments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_feedbacks
- **Source Script**: `04-migration-scripts/crewing/seafarer_feedbacks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.feedback_comments`
- **New Path**: `smac_crewing_migration.public.seafarer_feedbacks`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Feedbacks (`feedback_comments` → `seafarer_feedbacks`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `DISTINCT ON (uuid)` deduplicates source rows sharing the same uuid
- `seafarer_id` via `seafarer_id_mapping`; nil UUID fallback if unmapped
- `feedback_type_id` via `feedback_type_id_mapping` (`table_mappings` → `seafarer_feedback_types`)
- `feedback_category_id` via `feedback_category_id_mapping` (`enum.feedbackreasontype.identifier`); fallback to first SMAC category
- `company_id`, `vessel_id` via `table_mappings` lookups
- `vessel_revision_id` from active vessel revision (`revision_status = 5`) per mapped vessel
- `has_attachments` derived from SAC `attachments` array length
- `workflow_status` hardcoded `'approved'`; `status` from `deleted_at` (Case 1)
- `audit_info` merges `build_audit_info()` with `created_at`/`updated_at` timestamps
- Requires `seafarers`, `seafarer_feedback_types`, `seafarer_feedback_categories` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_feedbacks` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_feedback_types`, `seafarer_feedback_categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `feedback_type_id_mapping` | Delete mappings from migration.table_mappings | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `feedback_category_id_mapping` | FK lookup | `legacy_id`, `target_id` | - | `synergy_master` |
| `company_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_revision_id_mapping` | Create lookup tables for foreign keys | `new_vessel_id`, `active_revision_id` | - | `smac_master_migration` |

### `feedback_type_id_mapping`

- **Purpose**: Delete mappings from migration.table_mappings
- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE feedback_type_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''seafarer_feedback_types'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### `feedback_category_id_mapping`

- **Output columns**: legacy_id, target_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    id::bigint AS legacy_id,
    identifier AS target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM enum.feedbackreasontype'
) AS t(id integer, identifier uuid);
```

### `company_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''companies'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### `vessel_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### `vessel_revision_id_mapping`

- **Purpose**: Create lookup tables for foreign keys
- **Output columns**: new_vessel_id, active_revision_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; `DISTINCT ON (uuid)` |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` where `target_table = 'seafarers'` |
| 3 | `feedback_type_id` | bigint | `feedback_type_id` | uuid | Map via `feedback_type_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` → `seafarer_feedback_types` |
| 4 | `feedback_type_identifier` | bigint | `feedback_category_id` | uuid | Map via `feedback_category_id_mapping`; fallback first SMAC category | Lookup: `enum.feedbackreasontype.identifier` from `synergy_master` |
| 5 | `comment` | text | `comment` | text | `TRIM(comment)` | Direct copy with whitespace trimmed |
| 6 | `reference_date` | date | `reference_date` | date | Direct copy | Nullable |
| 7 | `attachments` | text[] | `has_attachments` | boolean | `array_length(attachments, 1) > 0` | Derived boolean from array presence |
| 8 | `other_remarks` | text | `other_remarks` | text | `TRIM(other_remarks)` | Direct copy |
| 9 | `company_id` | bigint | `company_id` | uuid | Map via `company_id_mapping` | Lookup: `table_mappings` where `target_table = 'companies'` |
| 10 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` | Lookup: `table_mappings` where `target_table = 'vessels'` |
| 11 | — | — | `workflow_status` | character varying(50) | Hardcoded `'approved'` | NOT NULL in SMAC; not in SAC source |
| 12 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `'deleted'`; else `'active'` | Case 1 — `deleted_at` only |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 15 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 17 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 18 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` \|\| `{created_at, updated_at}` | SAC has no audit_info column |
| 19 | — | — | `is_edited` | boolean | Hardcoded `false` | NOT NULL in SMAC; not in SAC source |
| 20 | `vessel_id` | bigint | `vessel_revision_id` | uuid | Active revision from `vessel_revision_id_mapping`; nil UUID fallback | Lookup: `vessel.vessel_revisions` where `revision_status = 5` |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `attachments` array content migrated separately via `seafarer_feedbackcomment_attachments` / `seafarer_feedbackcorrespondence_attachments` scripts.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_feedback_categories`
- `seafarer_feedback_types`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Feedback Type ID Mapping
**Purpose**: Delete mappings from migration.table_mappings
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE feedback_type_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''seafarer_feedback_types'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### 2. Feedback Category ID Mapping
**Output columns**: `legacy_id, target_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    id::bigint AS legacy_id,
    identifier AS target_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM enum.feedbackreasontype'
) AS t(id integer, identifier uuid);
```

### 3. Company ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''companies'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### 4. Vessel ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT legacy_id::bigint AS legacy_id, new_id AS target_id
FROM dblink('smac_master_migration',
    'SELECT source_id as legacy_id, target_id as new_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(legacy_id text, new_id uuid)
WHERE legacy_id ~ '^[0-9]+$';
```

### 5. Vessel Revision ID Mapping
**Purpose**: Create lookup tables for foreign keys
**Output columns**: `new_vessel_id, active_revision_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM dblink('smac_master_migration',
    'SELECT id, vessel_id, revision_status, created_at
     FROM vessel.vessel_revisions
     WHERE revision_status = 5
     ORDER BY vessel_id, created_at DESC'
) AS vr(id uuid, vessel_id uuid, revision_status integer, created_at timestamp)
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/crewing/seafarer_feedbacks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_feedbacks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_feedbacks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
