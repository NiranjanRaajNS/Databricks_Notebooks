# Table Mapping: contract_reviewers → contract_reviewers

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: contract_reviewers
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: contract_reviewers
- **Source Script**: `04-migration-scripts/crewing/contract_reviewers_migration.sql`

- **Legacy Path**: `synergy_manning.public.contract_reviewers`
- **New Path**: `smac_crewing_migration.public.contract_reviewers`

## Business Key

- **Composite Key**: (`contract_agreement_id`, `reviewer_id`, `email`, `role`)
- **Source (orchestration)**: Contract Reviewers (`contract_reviewers` → `contract_reviewers`)

## Migration Notes

- Generates new UUID for id (source has bigint, no uuid column)
- Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements
- Maps reviewer_id from reviewer_id (text) - parses as UUID if valid format, otherwise generates new UUID (target is NOT NULL)
- Maps remarks from reason_for_reject (text)
- Maps is_verified from approved_on (if approved_on IS NOT NULL, then true, else false)
- Maps verified_at from approved_on (timestamp)
- Maps verification_notes from reason_for_reject (text)
- Maps status from status (varchar, default '')
- Sets default values: workflow_status_id (empty GUID), verified_by_id (NULL), approval_level (1)
- Requires contract_agreements to be migrated first
- Migrates contract_reviewers table. Generates new UUIDs for id column (source has bigint, no uuid column). Maps contract_agreement_id from contract_agreement_id (bigint) via migration.table_mappings to contract_agreements. Maps reviewer_id from reviewer_id (text) - parses as UUID if valid format, otherwise generates new UUID (target is NOT NULL). Maps remarks and verification_notes from reason_for_reject (text). Maps is_verified from approved_on (if approved_on IS NOT NULL, then false, else false). Maps verified_at from approved_on (timestamp). Maps status from status (varchar, default ''). Sets defaults for new fields: workflow_status_id (empty GUID), verified_by_id (NULL), approval_level (1), tenant_id (DEFAULT_TENANT_ID), created_at/updated_at (NOW()). Uses standardized SMAC audit_info structure. Requires contract_agreements to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.contract_reviewers` before insert (full table reload).
- Orchestration dependencies: `contract_agreements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `contract_agreement_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `contract_agreement_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=contract_agreements

```sql
CREATE TEMP TABLE contract_agreement_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'contract_reviewers'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | derived | - | contract_agreement_id | - | COALESCE(ca_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) AS contract_agreement_id | COALESCE(ca_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | reviewer_id | - | reviewer_id | - | CASE WHEN legacy_data.reviewer_id IS NOT NULL AND legacy_data.reviewer_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.reviewer_id::uuid E... | CASE WHEN legacy_data.reviewer_id IS NOT NULL AND legacy_data.reviewer_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.reviewer_id::uuid E... |
| 4 | reason_for_reject | - | remarks | - | NULLIF(TRIM(legacy_data.reason_for_reject), '') AS remarks | NULLIF(TRIM(legacy_data.reason_for_reject), '') |
| 5 | derived | - | workflow_status_id | - | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS workflow_status_id | COALESCE( workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 6 | approved_on | - | is_verified | - | CASE WHEN legacy_data.approved_on IS NOT NULL THEN true ELSE false END AS is_verified | CASE WHEN legacy_data.approved_on IS NOT NULL THEN true ELSE false END |
| 7 | approved_on | - | verified_at | - | legacy_data.approved_on AS verified_at | legacy_data.approved_on |
| 8 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 9 | reason_for_reject | - | verification_notes | - | NULLIF(TRIM(legacy_data.reason_for_reject), '') AS verification_notes | NULLIF(TRIM(legacy_data.reason_for_reject), '') |
| 10 | is_active | - | status | - | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END AS status | CASE WHEN legacy_data.is_active = true THEN 'Active' ELSE 'Inactive' END |
| 11 | derived | - | tenant_id | - | v_default_tenant_id AS tenant_id | v_default_tenant_id |
| 12 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 13 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 16 | reason_for_reject, name, email | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, CASE WHEN legac... |
| 17 | role | - | approval_level | - | CASE WHEN UPPER(TRIM(legacy_data.role)) = 'DOCUMENTVERIFIER' THEN 1 WHEN UPPER(TRIM(legacy_data.role)) = 'DOCUMENTAPPROVER' THEN 2 ELSE 1 END AS approval_level | CASE WHEN UPPER(TRIM(legacy_data.role)) = 'DOCUMENTVERIFIER' THEN 1 WHEN UPPER(TRIM(legacy_data.role)) = 'DOCUMENTAPPROVER' THEN 2 ELSE 1 END |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `contract_agreements`
- `public.contract_agreements`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Contract Agreement ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='contract_agreements'`

```sql
CREATE TEMP TABLE contract_agreement_id_mapping AS
SELECT
    CASE
        WHEN source_id ~ '^[0-9]+$' THEN source_id::bigint
        ELSE NULL
    END AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'contract_agreements'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/contract_reviewers_migration.sql`

## Validation

- Run `05-validation/crewing/contract_reviewers_validation.sql` if available
- Run `06-rollback/crewing/contract_reviewers_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
