# Table Mapping: issuing_authorities → issuing_authorities

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: document
- **New Table**: issuing_authorities
- **Source Script**: `04-migration-scripts/master/issuing_authorities_migration.sql`

- **Legacy Path**: `synergy_seafarer.document.seafarer_documents.issuing_authority`
- **New Path**: `smac_master_migration.document.issuing_authorities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Document Issuing Authorities (`document_issuing_authorities` → `issuing_authorities`)

## Migration Notes

- Source: distinct `issuing_authority` from `synergy_seafarer.document.seafarer_documents` → `document.issuing_authorities`
- No SAC UUID column; `resolve_target_id()` with `p_target_id = NULL`
- `staging_issuing_authorities` matches `place_of_issue` → `public.states.name` for `country_id`
- `default_country` fallback when no state match
- Filter: `issuing_authority` not null/empty/`-`
- TRUNCATE target; `status` hardcoded Active (0)
- `created_at`/`updated_at` set to `NOW()`

## Special Considerations

- Extracts distinct issuing_authority values and maps to states/countries
- Script performs `TRUNCATE TABLE document.issuing_authorities` before insert (full table reload).

## ID Mappings

Intermediate lookup tables from the migration script.

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `default_country` | Fallback country when state match fails | `country_id` | - | - |

### `default_country`

- **Purpose**: First available country UUID used when place_of_issue does not match a state
- **Output columns**: country_id

```sql
CREATE TEMP TABLE default_country AS
SELECT id AS country_id
FROM public.countries
LIMIT 1;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `issuing_authority` | text | `id` | uuid | `migration.resolve_target_id()` — source_id = `InitCap(TRIM(issuing_authority))` truncated to 100; `p_target_id = NULL` | Idempotent text key |
| 2 | `issuing_authority` | text | `code` | text | `generate_meaningful_code(issuing_authority, NULL)` |  |
| 3 | `issuing_authority` | text | `name` | text | `LEFT(REGEXP_REPLACE(issuing_authority, '^\s+', ''), 100)` | Strip leading whitespace |
| 4 | `—` | — | `description` | text | `NULL` |  |
| 5 | `place_of_issue` | text | `country_id` | uuid | Match `place_of_issue` → `states.name` → `states.country_id`; fallback `default_country` | FK via state name |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 10 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 11 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 12 | `—` | — | `created_at` | timestamp | `NOW()` | Not from SAC record |
| 13 | `—` | — | `updated_at` | timestamp | `NOW()` | Not from SAC record |
| 14 | `—` | — | `deleted_at` | timestamp | `NULL` |  |
| 15 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** All other `seafarer_documents` columns.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/issuing_authorities_migration.sql`

## Validation

- Run `05-validation/master/issuing_authorities_validation.sql` if available
- Run `06-rollback/master/issuing_authorities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
