# Table Mapping: agents (id + iso_code) → agent_mapping

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: agents (id + iso_code)
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: agent_mapping
- **Source Script**: `04-migration-scripts/master/agent_mapping_migration.sql`

- **Legacy Path**: `synergy_master.public.agents (id + iso_code)`
- **New Path**: `smac_master_migration.public.agent_mapping`

## Business Key

- **Composite Key**: (`agent_id`, `mapping_type`, `mapped_value`)
- **Source (orchestration)**: Agent Mapping (`agent_mapping` → `agent_mapping`)

## Migration Notes

- No legacy `agent_mapping` table; rows derived from SAC `agents.iso_code` array and Manning `rps_company_details.seafarer_nationalities`
- Primary INSERT: one row per (agent, iso_code element) matched to `nationalities.code`; `ALL` elements skipped (sets `agents.is_all_nationalities` instead)
- Secondary INSERT: Manning agents from `rps_company_details` + `ship_management_companies` (recruitment/synergy companies only)
- `id` via `migration.resolve_target_id()` with composite source_id (`agent_id_nationality_CODE` or `manning_companyId_CODE`); idempotent via `id_mappings`
- `agent_id` resolved via `agent_id_mapping` (`migration.table_mappings` where `target_table = 'agents'`)
- `nationality_id` resolved by matching `UPPER(TRIM(iso_code))` to `nationalities.code`
- Filter: excludes agent named `'Synergy Maritime Recruitment Services Pvt Ltd'` from primary INSERT
- Script contains 2 INSERT blocks; column mapping documents shared target columns (both blocks use identical SMAC column set)

## Special Considerations

- Script performs `TRUNCATE TABLE public.agent_mapping` before insert (full table reload).
- Orchestration dependencies: `agents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `agent_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `nationalities_id_mapping` | Nationality code lookup | `normalized_code`, `nationality_id` | - | - |
| `manning_company_id_mapping` | FK lookup | `legacy_company_id`, `target_company_id` | `?.?.ship_management_companies` → `?.public.companies` | - |
| `manning_agent_by_company` | Resolve in-house manning agent per company | `company_id`, `agent_id` | - | - |

### `agent_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=public, target_table=agents

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'agents'
  AND target_schema = 'public'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `nationalities_id_mapping`

- **Purpose**: Get legacy row coun
- **Output columns**: normalized_code, nationality_id

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) AS normalized_code,
    n.id AS nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

### `manning_company_id_mapping`

- **Output columns**: legacy_company_id, target_company_id
- **migration.table_mappings**: source_table=ship_management_companies, target_schema=public, target_table=companies

```sql
CREATE TEMP TABLE manning_company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS target_company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_schema = 'public'
  AND tm.target_db = current_database()
  AND tm.source_id ~ '^[0-9]+$';
```

### `manning_agent_by_company`

- **Purpose**: Resolve in-house manning agent per company for secondary Manning INSERT
- **Output columns**: company_id, agent_id

```sql
CREATE TEMP TABLE manning_agent_by_company AS
SELECT c.id AS company_id, a.id AS agent_id
FROM public.companies c
JOIN public.company_services cs ON cs.company_id = c.id AND cs.deleted_at IS NULL
JOIN public.service_types st ON st.id = cs.service_type_id AND st.name = 'Crewing' AND st.deleted_at IS NULL
JOIN public.agents a ON TRIM(a.name) = TRIM(c.name) AND a.company_id = c.id AND a.deleted_at IS NULL
JOIN public.agent_types at ON at.id = a.agent_type_id AND at.name = 'Manning Agent'
WHERE c.is_inhouse_company = true AND c.deleted_at IS NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `iso_code` | bigint, character varying[] | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text \|\| '_nationality_' \|\| UPPER(TRIM(iso_element))` (Manning block: `manning_{company_id}_{CODE}`) | Idempotent UUID; no SAC `identifier` column |
| 2 | `id` | bigint | `agent_id` | uuid | Map via `agent_id_mapping` on `legacy_id = id` | Lookup: `migration.table_mappings` where `target_table = 'agents'` |
| 3 | — | — | `mapping_type` | text | Hardcoded `'Nationality'` | Junction type; not a SAC column |
| 4 | `iso_code` | character varying[] | `nationality_id` | uuid | Unnest array; match `UPPER(TRIM(element))` to `nationalities.code` via `nationalities_id_mapping` | Skip `ALL` and empty elements; Manning block uses `seafarer_nationalities` JSON array |
| 5 | — | — | `port_id` | uuid | `NULL` | No port mapping in current script |
| 6 | `created_at` | timestamp without time zone | `effective_from` | timestamp without time zone | `COALESCE(created_at, NOW())` (Manning block: `NOW()`) | Effective start of nationality mapping |
| 7 | — | — | `effective_until` | timestamp without time zone | `NULL` | No end date in SAC source |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 9 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 10 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 11 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 12 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 13 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 14 | — | — | `status` | integer | `:'DEFAULT_STATUS'::integer` from `constants.sql` | Default: Active (0); not in SAC source |
| 15 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` (Manning block: `NOW()`) | Direct copy with fallback |
| 16 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` (Manning block: `NOW()`) | Direct copy with fallback |
| 17 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC agents have no soft-delete on mapping rows |
| 18 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Standardized SMAC audit structure; no `legacy_id` (composite source_id in `id_mappings`) |
| 20 | — | — | `tags` | text[] | Empty array `'{}'` | Not populated from SAC source |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** `name`, `company_id`, `agent_type_id`, and other `agents` attributes — used only for FK/filter logic, not stored on `agent_mapping`.

**Post-migration changes (not from SAC column mapping):**
- UPDATE `agents.is_all_nationalities = true` when SAC `iso_code` or Manning `seafarer_nationalities` contains `ALL`

## Foreign Key Dependencies

### Prerequisites (from source script)

- `agents`
- `public.agents`
- `public.companies`
- `public.nationalities`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Agent ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='agents'`

```sql
CREATE TEMP TABLE agent_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'agents'
  AND target_schema = 'public'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Nationalities ID Mapping
**Purpose**: Get legacy row coun
**Output columns**: `normalized_code, nationality_id`

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) AS normalized_code,
    n.id AS nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

### 3. Manning Company ID Mapping
**Output columns**: `legacy_company_id, target_company_id`
**migration.table_mappings**: `ship_management_companies` → `companies`

```sql
CREATE TEMP TABLE manning_company_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_company_id,
    tm.target_id AS target_company_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'companies'
  AND tm.source_table = 'ship_management_companies'
  AND tm.target_schema = 'public'
  AND tm.target_db = current_database()
  AND tm.source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/master/agent_mapping_migration.sql`

## Validation

- Run `05-validation/master/agent_mapping_validation.sql` if available
- Run `06-rollback/master/agent_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
