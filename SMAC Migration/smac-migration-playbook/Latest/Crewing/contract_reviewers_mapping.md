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

- `migration.resolve_target_id()` with `p_target_id = NULL` (SAC bigint `id`)
- Excludes reviewers for contracts with status CLOSED/VOID on parent `vessel_contracts`
- `contract_agreement_id` via `contract_agreement_id_mapping`
- `reviewer_id`: parse UUID from text or `gen_random_uuid()`
- `workflow_status_id` from `workflow_status_lookup` (Approve→APPROVED, Pending→PENDINGAPPROVAL, Reject→REJECTED)
- `approval_level` from `role` (DocumentVerifier=1, DocumentApprover=2)
- Batch insert (20k rows); `created_at`/`updated_at` set to `NOW()` (not from SAC)
- Requires `contract_agreements` migrated first

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
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `contract_agreement_id` | bigint | `contract_agreement_id` | uuid | Map via `contract_agreement_id_mapping`; default nil UUID | Lookup: `contract_agreements` |
| 3 | `reviewer_id` | text | `reviewer_id` | uuid | Valid UUID regex → cast; else `gen_random_uuid()` | NOT NULL in SMAC |
| 4 | `reason_for_reject` | text | `remarks` | text | `NULLIF(TRIM(reason_for_reject), '')` | Nullable |
| 5 | `status` | character varying | `workflow_status_id` | uuid | Map via `workflow_status_lookup` (Approve/Pending/Reject) | Lookup: dblink `workflow_status` |
| 6 | `approved_on` | timestamp without time zone | `is_verified` | boolean | `approved_on IS NOT NULL` → true; else false | Derived |
| 7 | `approved_on` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | Nullable |
| 8 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC |
| 9 | `reason_for_reject` | text | `verification_notes` | text | `NULLIF(TRIM(reason_for_reject), '')` | Same source as `remarks` |
| 10 | `is_active` | boolean | `status` | text | `is_active = true` → `Active`; else `Inactive` | Text status |
| 11 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 12 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not sourced from SAC |
| 13 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not sourced from SAC |
| 14 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 15 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at` |
| 16 | `reason_for_reject`, `name`, `email` | text | `audit_info` | jsonb | `migration.build_audit_info()` — reject reason/name/email in `notes` | Standardized SMAC audit |
| 17 | `role` | character varying | `approval_level` | integer | DocumentVerifier→1, DocumentApprover→2; else 1 | NOT NULL |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `contract_id`, `email`, `name` (name/email used only in audit `notes`); `status` varchar mapped to `workflow_status_id`, not stored as separate SAC column in target.

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
