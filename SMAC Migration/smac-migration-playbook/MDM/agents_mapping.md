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

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.agents` before insert (full table reload).
- Orchestration dependencies: `agent_types`, `countries`

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
| 1 | derived | - | id | - | VALUES (seed/fixed rows) | VALUES (seed/fixed rows) |
| 2 | - | - | code | - | See source script | See source script |
| 3 | - | - | name | - | See source script | See source script |
| 4 | - | - | description | - | See source script | See source script |
| 5 | - | - | global_agent | - | See source script | See source script |
| 6 | - | - | country_id | - | See source script | See source script |
| 7 | - | - | agent_type_id | - | See source script | See source script |
| 8 | - | - | phone_number | - | See source script | See source script |
| 9 | - | - | email | - | See source script | See source script |
| 10 | - | - | address | - | See source script | See source script |
| 11 | - | - | tenant_id | - | See source script | See source script |
| 12 | - | - | version | - | See source script | See source script |
| 13 | - | - | defined_by | - | See source script | See source script |
| 14 | - | - | workflow_status | - | See source script | See source script |
| 15 | - | - | status | - | See source script | See source script |
| 16 | - | - | level | - | See source script | See source script |
| 17 | - | - | created_at | - | See source script | See source script |
| 18 | - | - | updated_at | - | See source script | See source script |
| 19 | - | - | audit_info | - | See source script | See source script |
| 20 | - | - | tags | - | See source script | See source script |
| 21 | - | - | company_id | - | See source script | See source script |
| 22 | - | - | is_inhouse | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
