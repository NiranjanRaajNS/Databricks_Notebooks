# Table Mapping: managementservicetypelist → management_services

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: managementservicetypelist
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: management_services
- **Source Script**: `04-migration-scripts/master/management_services_migration.sql`

- **Legacy Path**: `synergy_master.enum.managementservicetypelist`
- **New Path**: `smac_master_migration.vessel.management_services`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Managementservicetypelist (`managementservicetypelist` → `management_services`)

## Migration Notes

- Source: `synergy_master.enum.managementservicetypelist` → `vessel.management_services`
- SAC `identifier` preserved via `resolve_target_id()` with `p_target_id = identifier`
- Pre-migration duplicate UUID check on `identifier`
- Depends on `public.service_types` migrated first
- `service_type_id_mapping`: legacy `enum.fdlservicetype` name match; `manning` → `crewing`; fallback `technical`
- Filter: non-empty `name`
- `status` hardcoded Active (0); `updated_at` set to `NOW()`
## Special Considerations

- Script performs `TRUNCATE TABLE vessel.management_services` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `service_type_id_mapping` | Clear existing data from target tab | `legacy_service_type_identifier`, `new_id` | - | `synergy_master` |

### `service_type_id_mapping`

- **Purpose**: Clear existing data from target tab
- **Output columns**: legacy_service_type_identifier, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE service_type_id_mapping AS
SELECT DISTINCT
    legacy_st.identifier AS legacy_service_type_identifier,
    COALESCE(
        CASE
            WHEN LOWER(TRIM(legacy_st.name)) = 'manning' THEN smac_st_crewing.id
            ELSE smac_st_match.id
        END,
        smac_st_technical.id
    ) AS new_id
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.fdlservicetype WHERE identifier IS NOT NULL'
) AS legacy_st(identifier uuid, name text)
LEFT JOIN public.service_types smac_st_crewing ON LOWER(TRIM(smac_st_crewing.name)) = 'crewing'
LEFT JOIN public.service_types smac_st_match ON LOWER(TRIM(smac_st_match.name)) = LOWER(TRIM(legacy_st.name))
LEFT JOIN public.service_types smac_st_technical ON LOWER(TRIM(smac_st_technical.name)) = 'technical'
WHERE legacy_st.identifier IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, identifier` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` |  |
| 2 | `name, identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` |  |
| 3 | `name` | text | `name` | text | `TRIM(name)` |  |
| 4 | `service_type_id` | uuid | `service_type_id` | uuid | Map via `service_type_id_mapping` on legacy fdlservicetype identifier; fallback zero-UUID | FK lookup |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 6 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 7 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 8 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 9 | `—` | — | `status` | integer | Hardcoded `0` (Active) |  |
| 10 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 11 | `—` | — | `updated_at` | timestamp | `NOW()` | Not preserved from source |
| 12 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |

**SAC columns not migrated:** Legacy bigint `id` used only as `source_id` in mappings.

**SMAC columns not migrated:** None beyond defaults.",
)

# --- ml_forms_templates ---
set_update(
    "ml_forms_templates",
    [
        "- Sources: JOIN `ml_template_details` + `ml_template_form_master` → `crewing.ml_forms_templates`",
        "- Target `id` = `ml_template_details.id` preserved via `resolve_target_id()` with `p_target_id = id`",
        "- Each template version in details becomes a separate SMAC row",
        "- `form_number` generated: `FORM-` + zero-padded row number",
        "- `company_id` initially `DEFAULT_TENANT_ID`; post-migration UPDATE to `companies` where `code='SMRSPL'`",
        "- Filter: non-empty `template_name` and `code`",
        "- `status` Case 1 from coalesced detail/master `deleted_at`",
    ],
    [
        row(1, "id (details)", "uuid", "id", "uuid", "`migration.resolve_target_id()` — source_id = `ml_template_details.id::text`; `p_target_id = id`", "Pattern 4
## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Service Type ID Mapping
**Purpose**: Clear existing data from target tab
**Output columns**: `legacy_service_type_identifier, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE service_type_id_mapping AS
SELECT DISTINCT
    legacy_st.identifier AS legacy_service_type_identifier,
    COALESCE(
        CASE
            WHEN LOWER(TRIM(legacy_st.name)) = 'manning' THEN smac_st_crewing.id
            ELSE smac_st_match.id
        END,
        smac_st_technical.id
    ) AS new_id
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.fdlservicetype WHERE identifier IS NOT NULL'
) AS legacy_st(identifier uuid, name text)
LEFT JOIN public.service_types smac_st_crewing ON LOWER(TRIM(smac_st_crewing.name)) = 'crewing'
LEFT JOIN public.service_types smac_st_match ON LOWER(TRIM(smac_st_match.name)) = LOWER(TRIM(legacy_st.name))
LEFT JOIN public.service_types smac_st_technical ON LOWER(TRIM(smac_st_technical.name)) = 'technical'
WHERE legacy_st.identifier IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/management_services_migration.sql`

## Validation

- Run `05-validation/master/management_services_validation.sql` if available
- Run `06-rollback/master/management_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
