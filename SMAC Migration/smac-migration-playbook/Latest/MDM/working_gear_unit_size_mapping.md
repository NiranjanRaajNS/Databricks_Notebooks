# Table Mapping: working_gear_unit_size → working_gear_unit_size

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: working_gear_unit_size
- **Source Script**: `04-migration-scripts/master/working_gear_unit_size_migration.sql`

- **Legacy Path**: `synergy_manning_po.public.ppe_component_masters.measurement (JSONB)`
- **New Path**: `smac_master_migration.crewing.working_gear_unit_size`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Working Gear Unit Size (`ppe_component_masters` → `working_gear_unit_size`)

## Migration Notes

- Source: `synergy_manning_po.public.ppe_component_masters` — `measurement` JSONB array flattened
- SAC `\"Id\"` (UUID) preserved for first element; composite `source_id` for additional elements
- Pre-migration duplicate UUID check on SAC `\"Id\"` column
- `working_gear_id` matched from parent `name` → `crewing.working_gear.name`
- `code` generated from element name/size via `generate_meaningful_code()`
- Filter: skips NULL/empty measurement elements; `WHERE s.name IS NOT NULL`
- `status` derived from parent `deleted_at` (Case 1)
- TRUNCATE uses CASCADE (handles FK from working_gear)
## Special Considerations

- Extract measurement JSONB array from ppe_component_masters
- Script performs `TRUNCATE TABLE crewing.working_gear_unit_size` before insert (full table reload).
- Orchestration dependencies: `working_gear`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `working_gear_id_mapping` | Check f | `legacy_name`, `working_gear_id` | - | `synergy_manning_po` |

### `working_gear_id_mapping`

- **Purpose**: Check f
- **Output columns**: legacy_name, working_gear_id
- **dblink connection**: `synergy_manning_po`

```sql
CREATE TEMP TABLE working_gear_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(legacy_data.name)))
    UPPER(TRIM(legacy_data.name)) AS legacy_name,
    wg.id AS working_gear_id
FROM dblink('synergy_manning_po',
    'SELECT DISTINCT name FROM public.ppe_component_masters WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS legacy_data(name text)
JOIN crewing.working_gear wg ON UPPER(TRIM(wg.name)) = UPPER(TRIM(legacy_data.name))
WHERE TRIM(legacy_data.name) != '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `\"Id\", row_num` | uuid, integer | `id` | uuid | `migration.resolve_target_id()` — composite source_id; first row preserves `\"Id\"` UUID | One row per measurement element |
| 2 | `measurement element` | jsonb/text | `name` | text | String value or object `name`/`size`/`code` field | Per array element |
| 3 | `measurement element name, code` | text | `code` | text | `generate_meaningful_code(name, code_from_json)` | Generated per element |
| 4 | `—` | — | `description` | text | Hardcoded NULL | Not in measurement JSON |
| 5 | `—` | — | `level` | numeric | Hardcoded `0` | Not in measurement JSON |
| 6 | `name` | text | `working_gear_id` | uuid | Match parent `ppe_component_masters.name` → `crewing.working_gear` via `working_gear_id_mapping` | FK lookup |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 8 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in measurement JSON |
| 9 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 12 | `deleted_at` | timestamp with time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Inherited from parent row |
| 13 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From parent row |
| 14 | `updated_at` | timestamp with time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | From parent row |
| 15 | `deleted_at` | timestamp with time zone | `deleted_at` | timestamp without time zone | Direct copy from parent | Soft-delete preserved |
| 16 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in measurement JSON |
| 17 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in measurement JSON |
| 18 | `created_by, updated_by` | text | `audit_info` | jsonb | `migration.build_audit_info()` with creator/updater names in `p_notes` | From parent row audit fields |

**SAC columns not migrated:** `sizable`, `is_adhoc`, `measurement` JSON structure itself — parent fields except per-element values.

**Note:** Depends on `working_gear` migrated first for FK resolution.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `working_gear`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Working Gear ID Mapping
**Purpose**: Check f
**Output columns**: `legacy_name, working_gear_id`
**dblink**: `synergy_manning_po`

```sql
CREATE TEMP TABLE working_gear_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(legacy_data.name)))
    UPPER(TRIM(legacy_data.name)) AS legacy_name,
    wg.id AS working_gear_id
FROM dblink('synergy_manning_po',
    'SELECT DISTINCT name FROM public.ppe_component_masters WHERE name IS NOT NULL AND TRIM(name) != '''''
) AS legacy_data(name text)
JOIN crewing.working_gear wg ON UPPER(TRIM(wg.name)) = UPPER(TRIM(legacy_data.name))
WHERE TRIM(legacy_data.name) != '';
```

Full migration context: `04-migration-scripts/master/working_gear_unit_size_migration.sql`

## Validation

- Run `05-validation/master/working_gear_unit_size_validation.sql` if available
- Run `06-rollback/master/working_gear_unit_size_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
