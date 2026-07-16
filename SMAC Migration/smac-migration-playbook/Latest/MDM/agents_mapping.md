# Table Mapping: agents → agents

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: agents
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: agents
- **Source Script**: `04-migration-scripts/master/agents_migration.sql`

- **Legacy Path**: `synergy_master.public.agents`
- **New Path**: `smac_master_migration.public.agents`

## Business Key

- **Business Key**: `agent_code`
- **Source (orchestration)**: Agents (`agents` → `agents`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `code` generated from `name` + `identifier` via `generate_meaningful_code()`
- `agent_type_id` mapped via `agent_type_id_mapping` (`migration.table_mappings` where `target_table = 'agent_types'`)
- `global_agent` derived: `iso_code` contains `'ALL'` OR `agent_sub_type_id = 1`
- `is_inhouse` derived: `agent_sub_type_id = 1` (InhouseDefaultAgent)
- `phone`/`email` arrays: first element extracted for `phone_number`/`email`
- `address` text wrapped into JSONB with `addressLine1`
- `status` mapped from SAC `status` string/integer (Case 1 — no `deleted_at` column)
- Pre-migration duplicate UUID check on SAC `uuid` column
- Manning agents INSERT block is commented out in migration script

## Special Considerations

- Script performs `TRUNCATE TABLE public.agents` before insert (full table reload)
- Orchestration dependencies: `agent_types`
- `country_id` always set to NULL in migration (not resolved from `iso_code`)

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `agent_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `agent_type_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=agent_types

```sql
CREATE TEMP TABLE agent_type_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'agent_types'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `identifier` | text | `code` | text | `generate_meaningful_code(TRIM(name), TRIM(identifier))` | Generated business code; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy with whitespace trimmed; NOT NULL in SMAC |
| 4 | — | — | `description` | text | `NULL` | No equivalent in SAC; not populated |
| 5 | `iso_code`, `agent_sub_type_id` | character varying[], bigint | `global_agent` | boolean | `true` when `'ALL' = ANY(iso_code)` OR `agent_sub_type_id = 1` | Derived flag; SAC `global_agent` boolean column not used directly |
| 6 | — | — | `country_id` | uuid | `NULL` | Not resolved in migration script despite `iso_code` array in SAC |
| 7 | `agent_type_id` | bigint | `agent_type_id` | uuid | Map via `agent_type_id_mapping` | Lookup: `migration.table_mappings` where `target_table = 'agent_types'` |
| 8 | `phone` | text[] | `phone_number` | text | First array element `phone[1]` when array non-empty; else NULL | SAC stores phone as array |
| 9 | `email` | text[] | `email` | text | First array element `email[1]` when array non-empty; else NULL | SAC stores email as array |
| 10 | `address` | text | `address` | jsonb | `jsonb_build_object` with `addressLine1` = trimmed address; other fields NULL | Plain text address wrapped in SMAC address JSONB structure |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 12 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 13 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 14 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 15 | `status` | text | `status` | integer | Map string/numeric status to Active/Draft/Inactive/Deleted integers | Per project rule Case 2 (status only, no `deleted_at`) |
| 16 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 17 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 18 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 19 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — UUID extracted from formatted string (`"ROLE - uuid - email - name"`); names in `notes` | SAC stores composite audit strings; second segment parsed as UUID |
| 20 | `name`, `identifier` | text | `tags` | text[] | Distinct array: lowercase generated `code` tag + normalized lowercase `name` tag | Derived search tags; not in SAC source |
| 21 | `agent_sub_type_id` | bigint | `is_inhouse` | boolean | `true` when `agent_sub_type_id = 1` (InhouseDefaultAgent) | SAC AgentSubTypes: 1 = Inhouse, 2 = External |

**SAC columns not migrated:** `global_agent` (boolean), `port_id` — not mapped to SMAC columns; `global_agent` SMAC value is derived from `iso_code`/`agent_sub_type_id`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `agent_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Agent Type ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='agent_types'`

```sql
CREATE TEMP TABLE agent_type_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'agent_types'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/agents_migration.sql`

## Validation

- Run `05-validation/master/agents_validation.sql` if available
- Run `06-rollback/master/agents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
