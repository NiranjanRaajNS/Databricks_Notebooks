# Table Mapping: relief_compliance → seafarer_assignment_document_summaries

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: relief_compliance
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_assignment_document_summaries
- **Source Script**: `04-migration-scripts/crewing/seafarer_assignment_document_summaries_migration.sql`

- **Legacy Path**: `synergy_manning.public.relief_compliance`
- **New Path**: `smac_crewing_migration.public.seafarer_assignment_document_summaries`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Assignment Document Summaries (`relief_compliance` → `seafarer_assignment_document_summaries`)

## Migration Notes

- SAC `synergy_manning.relief_compliance` → SMAC `public.seafarer_assignment_document_summaries`
- SAC `id` (uuid) preserved directly as SMAC `id` (no `resolve_target_id`)
- `seafarer_id` = SAC `seafarer_uuid` (direct copy — already UUID)
- `vessel_id` resolved via `vessel_imo_mapping` matching SAC `vessel_imo` to SMAC `vessel.vessels.imo_number`
- `assignment_id`, `includes_from`, `includes_to` from `relief_summary_mapping` join on relief_id + seafarer_id + vessel IMO
- `relief_summary` join filters non-closed relief/contract states
- `relief_candidates_id` set to `NULL` per requirements
- `status` hardcoded `'Active'`; `available_documents` defaults to `'[]'::jsonb`
- `last_change_at` = `COALESCE(updated_at, created_at)`
- `audit_info` via `migration.build_audit_info()` with all-null params (no SAC audit columns)
- Requires `seafarer_reliefs` and `relief_candidates` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_assignment_document_summaries` before insert (full table reload).
- Orchestration dependencies: `seafarer_reliefs`, `relief_candidates`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relief_summary_mapping` | FK lookup | `relief_compliance_id`, `rs.assignment_id`, `includes_from`, `includes_to`, `rs.contract_start_date`, `rs.contract_end_date` | - | `synergy_manning` |
| `vessel_imo_mapping` | Create relief_summary mapping table | `vessel_id`, `imo_number` | - | `smac_master_migration` |

### `relief_summary_mapping`

- **Output columns**: relief_compliance_id, rs.assignment_id, includes_from, includes_to, rs.contract_start_date, rs.contract_end_date
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_summary_mapping AS
SELECT DISTINCT ON (rc.id)
    rc.id AS relief_compliance_id,
    rs.assignment_id,
    rs.contract_start_date AS includes_from,
    rs.contract_end_date AS includes_to,
    rs.contract_start_date,
    rs.contract_end_date
FROM dblink('synergy_manning',
    'SELECT
        id,
        relief_id,
        seafarer_id,
        vessel_imo
     FROM public.relief_compliance
     WHERE id IS NOT NULL'
) AS rc(
    id uuid,
    relief_id bigint,
    seafarer_id bigint,
    vessel_imo bigint
)
INNER JOIN public.relief_summary rs ON
    (rs.onboard_relief_id = rc.relief_id OR rs.planned_relief_id = rc.relief_id)
    AND rs.seafarer_id = rc.seafarer_id
    AND TRIM(rs.vessel_imo_number) = rc.vessel_imo::text
WHERE rs.assignment_id IS NOT NULL
  AND rs.seafarer_id IS NOT NULL
  AND rs.vessel_imo_number IS NOT NULL
  AND TRIM(rs.vessel_imo_number) != ''





  AND (
    (COALESCE(UPPER(TRIM(rs.onboard_relief_state)), '') NOT IN ('CLOSED', 'CLOSE')
     AND COALESCE(UPPER(TRIM(rs.contract_status)), '') NOT IN ('CLOSED', 'CLOSE'))
    OR COALESCE(UPPER(TRIM(rs.planned_relief_state)), '') NOT IN ('CLOSED', 'CLOSE')
  );
```

### `vessel_imo_mapping`

- **Purpose**: Create relief_summary mapping table
- **Output columns**: vessel_id, imo_number
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    TRIM(v.imo_number) AS imo_number
FROM dblink('smac_master_migration',
    'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
) AS v(id uuid, imo_number text)
WHERE TRIM(v.imo_number) != '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | Direct copy | SAC UUID preserved as SMAC PK |
| 2 | via `relief_summary` | uuid | `assignment_id` | uuid | `relief_summary_map.assignment_id` | From `relief_summary` join on relief + seafarer + IMO |
| 3 | — | — | `relief_candidates_id` | uuid | `NULL` | Intentionally not populated |
| 4 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Direct copy | Already UUID in SAC |
| 5 | `vessel_imo` | bigint | `vessel_id` | uuid | Map via `vessel_imo_mapping` (`vessel.vessels.imo_number`) | LEFT JOIN on IMO match |
| 6 | `compliance_percentage` | numeric | `compliance_percentage` | numeric | Direct copy | |
| 7 | `available_documents` | jsonb | `available_documents` | jsonb | `COALESCE(available_documents, '[]'::jsonb)` | Defaults to empty array |
| 8 | via `relief_summary` | timestamp | `includes_from` | timestamp without time zone | `relief_summary_map.includes_from` (= `contract_start_date`) | Contract date range start |
| 9 | via `relief_summary` | timestamp | `includes_to` | timestamp without time zone | `relief_summary_map.includes_to` (= `contract_end_date`) | Contract date range end |
| 10 | `updated_at`, `created_at` | timestamp | `last_change_at` | timestamp without time zone | `COALESCE(updated_at, created_at)` | Most recent change timestamp |
| 11 | — | — | `status` | text | Hardcoded `'Active'` | SAC has no status column |
| 12 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 13 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 14 | `updated_at`, `created_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | |
| 15 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 16 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all NULL params | SAC has no audit columns |

**SMAC columns not migrated:** `deleted_at` — not in target schema or migration script.

**SAC columns not migrated:** `relief_id`, `seafarer_id` (bigint), `vessel_imo` — used only for join logic; `relief_id` not stored as separate SMAC column.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `relief_candidates`
- `seafarer_reliefs`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relief Summary ID Mapping
**Output columns**: `relief_compliance_id, rs.assignment_id, includes_from, includes_to, rs.contract_start_date, rs.contract_end_date`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE relief_summary_mapping AS
SELECT DISTINCT ON (rc.id)
    rc.id AS relief_compliance_id,
    rs.assignment_id,
    rs.contract_start_date AS includes_from,
    rs.contract_end_date AS includes_to,
    rs.contract_start_date,
    rs.contract_end_date
FROM dblink('synergy_manning',
    'SELECT
        id,
        relief_id,
        seafarer_id,
        vessel_imo
     FROM public.relief_compliance
     WHERE id IS NOT NULL'
) AS rc(
    id uuid,
    relief_id bigint,
    seafarer_id bigint,
    vessel_imo bigint
)
INNER JOIN public.relief_summary rs ON
    (rs.onboard_relief_id = rc.relief_id OR rs.planned_relief_id = rc.relief_id)
    AND rs.seafarer_id = rc.seafarer_id
    AND TRIM(rs.vessel_imo_number) = rc.vessel_imo::text
WHERE rs.assignment_id IS NOT NULL
  AND rs.seafarer_id IS NOT NULL
  AND rs.vessel_imo_number IS NOT NULL
  AND TRIM(rs.vessel_imo_number) != ''





  AND (
    (COALESCE(UPPER(TRIM(rs.onboard_relief_state)), '') NOT IN ('CLOSED', 'CLOSE')
     AND COALESCE(UPPER(TRIM(rs.contract_status)), '') NOT IN ('CLOSED', 'CLOSE'))
    OR COALESCE(UPPER(TRIM(rs.planned_relief_state)), '') NOT IN ('CLOSED', 'CLOSE')
  );
```

### 2. Vessel Imo ID Mapping
**Purpose**: Create relief_summary mapping table
**Output columns**: `vessel_id, imo_number`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_imo_mapping AS
SELECT DISTINCT
    v.id AS vessel_id,
    TRIM(v.imo_number) AS imo_number
FROM dblink('smac_master_migration',
    'SELECT id, imo_number FROM vessel.vessels WHERE imo_number IS NOT NULL AND TRIM(imo_number) != '''''
) AS v(id uuid, imo_number text)
WHERE TRIM(v.imo_number) != '';
```

Full migration context: `04-migration-scripts/crewing/seafarer_assignment_document_summaries_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_assignment_document_summaries_validation.sql` if available
- Run `06-rollback/crewing/seafarer_assignment_document_summaries_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
