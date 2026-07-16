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

## Special Considerations

- Script performs `TRUNCATE TABLE public.agent_mapping` before insert (full table reload).
- Orchestration dependencies: `agents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `agent_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `nationalities_id_mapping` | Get legacy row coun | `normalized_code`, `nationality_id` | - | - |
| `manning_company_id_mapping` | FK lookup | `legacy_company_id`, `target_company_id` | `?.?.ship_management_companies` → `?.public.companies` | - |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id, UPPER(TRIM(iso_ele.elem::text))) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'agents'::VARCHAR(100), legacy... |
| 2 | derived | - | agent_id | - | agent_map.new_id AS agent_id | agent_map.new_id |
| 3 | derived | - | mapping_type | - | 'Nationality'::text AS mapping_type | 'Nationality'::text |
| 4 | derived | - | nationality_id | - | nat_map.nationality_id AS nationality_id | nat_map.nationality_id |
| 5 | - | - | port_id | - | NULL | NULL::uuid |
| 6 | created_at | - | effective_from | - | COALESCE(legacy_data.created_at, NOW()) AS effective_ | COALESCE(legacy_data.created_at, NOW()) AS effective_ |
| 7 | - | - | effective_until | - | See source script | See source script |
| 8 | - | - | tenant_id | - | See source script | See source script |
| 9 | - | - | parent_id | - | See source script | See source script |
| 10 | - | - | level | - | See source script | See source script |
| 11 | - | - | version | - | See source script | See source script |
| 12 | - | - | defined_by | - | See source script | See source script |
| 13 | - | - | workflow_status | - | See source script | See source script |
| 14 | - | - | status | - | See source script | See source script |
| 15 | - | - | created_at | - | See source script | See source script |
| 16 | - | - | updated_at | - | See source script | See source script |
| 17 | - | - | deleted_at | - | See source script | See source script |
| 18 | - | - | archived_at | - | See source script | See source script |
| 19 | - | - | audit_info | - | See source script | See source script |
| 20 | - | - | tags | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

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
