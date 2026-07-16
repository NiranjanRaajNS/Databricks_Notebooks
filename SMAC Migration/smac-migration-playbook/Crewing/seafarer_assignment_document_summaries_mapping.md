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

- Preserves source UUID id column directly as target id (UUID PK)
- Uses seafarer_uuid directly from source table
- Maps vessel_id from vessel table using IMO number (vessel_imo from source)
- Gets assignment_id, contract_start_date, contract_end_date from relief_summary table
- Joins relief_summary using relief_id + seafarer_id + vessel_imo
- Sets status to 'Active'
- Maps includes_from and includes_to from contract dates
- Sets relief_candidates_id to NULL
- Sets default values: tenant_id from constants.sql
- Migrates relief_compliance to seafarer_assignment_document_summaries preserving UUID id. Maps relief_id to seafarer_reliefs via migration.table_mappings. Gets seafarer_id and vessel_id from shore.relief_candidates via relief_id. Maps compliance_percentage directly. Sets status to empty string (required NOT NULL, source has no status). Sets default values: tenant_id from constants.sql. Maps available_documents JSONB with default empty array. Maps relief_candidates_id from shore.relief_candidates table. Requires seafarer_reliefs and relief_candidates tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_assignment_document_summaries` before insert (full table reload).
- Orchestration dependencies: `seafarer_reliefs`, `relief_candidates`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `relief_summary_mapping` | FK lookup | `relief_compliance_id`, `rs.assignment_id`, `includes_` | - | `synergy_manning` |
| `vessel_imo_mapping` | Create relief_summary mapping table | `vessel_id`, `imo_number` | - | `smac_master_migration` |

### `relief_summary_mapping`

- **Output columns**: relief_compliance_id, rs.assignment_id, includes_
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
| 1 | id | - | id | - | legacy_data.id | legacy_data.id |
| 2 | derived | - | assignment_id | - | relief_summary_map.assignment_id | relief_summary_map.assignment_id |
| 3 | - | - | relief_candidates_id | - | NULL | NULL::uuid |
| 4 | seafarer_uuid | - | seafarer_id | - | legacy_data.seafarer_uuid AS seafarer_id | legacy_data.seafarer_uuid |
| 5 | derived | - | vessel_id | - | vessel_map.vessel_id | vessel_map.vessel_id |
| 6 | compliance_percentage | - | compliance_percentage | - | legacy_data.compliance_percentage AS compliance_percentage | legacy_data.compliance_percentage |
| 7 | available_documents | - | available_documents | - | COALESCE(legacy_data.available_documents, '[]'::jsonb) AS available_documents | COALESCE(legacy_data.available_documents, '[]'::jsonb) |
| 8 | derived | - | includes_from | - | relief_summary_map.includes_ | relief_summary_map.includes_ |
| 9 | - | - | includes_to | - | See source script | See source script |
| 10 | - | - | last_change_at | - | See source script | See source script |
| 11 | - | - | status | - | See source script | See source script |
| 12 | - | - | tenant_id | - | See source script | See source script |
| 13 | - | - | created_at | - | See source script | See source script |
| 14 | - | - | updated_at | - | See source script | See source script |
| 15 | - | - | archived_at | - | See source script | See source script |
| 16 | - | - | audit_info | - | See source script | See source script |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Relief Summary ID Mapping
**Output columns**: `relief_compliance_id, rs.assignment_id, includes_`
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
