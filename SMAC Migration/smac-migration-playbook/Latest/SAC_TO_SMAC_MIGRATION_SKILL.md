# SAC to SMAC Migration Skill

Comprehensive reference for migrating reporting views from SAC (`reporting_layer.sac_prod_seafarer_public.*`) to SMAC (`reporting_layer.smac_prod.*`) for Synergy Marine's crewing system.

**Use this when:**
- Migrating any SAC reporting table/view to SMAC
- Finding the SMAC equivalent of a SAC source table
- Writing queries against SMAC crewing data
- Validating migrated tables between systems

## Playbook & Mapping Files

This file lives in: `/Workspace/Users/niranjan.r@synergyship.com/smac-migration-playbook/Latest/`

### SAC Source Notebook
The SAC views are defined in: `/Data_Hub/SAC_Views/SAC TABLES SET -1`
Run `SHOW CREATE TABLE reporting_layer.sac_prod_seafarer_public.<TABLE_NAME>` to get the source DDL.

### To use as an Assistant Skill
Copy this file to your own workspace at: `~/.assistant/skills/sac-smac-migration/SKILL.md`
The assistant will then automatically load it when working on SAC-to-SMAC migration tasks.

---

---

## Migration Process

### Step 1: Get the SAC Source
1. Run `SHOW CREATE TABLE reporting_layer.sac_prod_seafarer_public.<TABLE_NAME>`
2. If it's a TABLE (not VIEW), find the INSERT/CREATE statement in the SAC notebook
3. Extract all source tables, JOIN conditions, and column transformations

### Step 2: Map SAC Tables to SMAC
- Use the table mapping below to identify SMAC equivalents
- Check the playbook for column-level mappings
- Watch for JSON fields that are now flat columns (engine specs, capacity, addresses)

### Step 3: Write the SMAC Query
- Use `CREATE OR REPLACE TABLE` with column mapping TBLPROPERTIES
- Apply all gotchas (contract table, JSON paths, datediff direction, CAST NULL, etc.)
- Filter `WHERE deleted_at IS NULL` on all SMAC source tables

### Step 4: Validate
- Compare row counts (target: 90-110% ratio)
- Find overlapping crew codes and spot-check on composite keys
- Categorize mismatches: UUID/INT (expected), case/format (cosmetic), true differences

---

## Schema & Table Mapping

### Crewing Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_seafarer_public.seafarers` | `seafarers` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_seafarer_public.sea_experiences` | `seafarer_sea_experiences` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_seafarer_public.appraisals` | `seafarer_appraisals` + `seafarer_appraisal_forms` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.vessel_contracts` | `seafarer_vessel_assignments` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.RELIEFS` | `seafarer_reliefs` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.SHORTLISTED_SEAFARERS` | `relief_candidates` | `curated_db.db_smac_prod_navitasai_crewing_shore` |
| `db_sac_prod_seafarer_public.SEAFARER_REMARKS` | `seafarer_remarks` | `curated_db.db_smac_prod_navitasai_crewing_shore` |
| *(contract data)* | `contract_agreements` (**NOT** `seafarer_contracts`) | `curated_db.db_smac_prod_navitasai_crewing_public` |

### Master Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_master_public.ranks` | `ranks` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_master_public.nationalities` | `nationalities` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_master_public.ship_management_companies` | `companies` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_seafarer_public.appraisal_types` | `appraisal_types` | `curated_db.db_smac_prod_navitasai_masters_crewing` |
| `db_sac_prod_seafarer_public.SEAFARER_PROFILE_REMARKS` | `profile_remark_reasons` | `curated_db.db_smac_prod_navitasai_masters_crewing` |

### Vessel Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_vessel_public.vessels` | `vessels` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.vessel_sub_categories` | `sub_categories` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.VESSEL_CATEGORIES` | `categories` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.fleets` | `fleets` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.fleets_vessels` | `fld_fleet_vessels` | `curated_db.db_smac_prod_navitasai_masters_vessel` |

### SMAC-Only Tables (no SAC equivalent)
| Table | Schema | Purpose |
|-------|--------|--------|
| `contract_agreements` | crewing_public | Contract details (448K rows) — CRITICAL: use this NOT seafarer_contracts |
| `appraisal_stages` | masters_crewing | Appraisal feedback stage names |
| `profile_remark_reasons` | masters_crewing | Specific inactive/deactivation reasons |
| `profile_remark_types` | masters_crewing | Remark type categories (DEACTIVATION, ACTIVATION, etc.) |
| `seafarer_profile_statuses` | masters_crewing | ACTIVE/INACTIVE status (2 rows) |
| `relief_states` | masters_crewing | Relief state codes |
| `genders` | masters_public | Gender lookup |

---

## Critical Rules & Gotchas

### 1. Soft Delete & Filtering
- **SMAC (curated_db)**: Pre-filtered by `_fivetran_active = true`
- **All SMAC tables**: Must also filter `WHERE deleted_at IS NULL`
- **SAC**: Used `_fivetran_deleted` pattern (different)

### 2. IDs: Integer → UUID
- SAC: integer IDs | SMAC: UUID strings
- Cross-system validation: JOIN on `crew_code`, never on ID

### 3. Contract Table (CRITICAL — MOST COMMON MISTAKE)
- **WRONG**: `seafarer_contracts` (109K rows)
- **CORRECT**: `contract_agreements` (448K rows) — has `start_date`, `end_date`, `status`
- FK: `seafarer_sea_experiences.contract_agreement_id` → `contract_agreements.id`

### 4. Engine Specifications JSON (PascalCase)
```json
{"DualFuel": false, "OutputPower": "8050", "EngineMakeName": "MAN B&W", "EngineModelName": "5S60ME-C8", "OutputPowerUnit": "kw"}
```
Use: `$.DualFuel`, `$.EngineMakeName`, `$.EngineModelName`, `$.OutputPower`, `$.OutputPowerUnit`

### 5. Cargo Capacity JSON
```sql
CONCAT(COALESCE(get_json_object(cargo_capacity_info, '$.capacity'), ''), ' ', COALESCE(get_json_object(cargo_capacity_info, '$.capacity_unit'), ''))
```

### 6. Experience Calculation
- CORRECT: `datediff(current_date(), CAST(sign_on_date AS DATE))` → positive
- WRONG: `datediff(sign_on_date, current_date())` → negative

### 7. Photon & Column Mapping
- Always `CAST(NULL AS STRING) AS col` (never bare `NULL AS col`)
- Avoid column names ending with underscore
- Always include: `TBLPROPERTIES ('delta.columnMapping.mode' = 'name', 'delta.minReaderVersion' = '2', 'delta.minWriterVersion' = '5')`

### 8. Rank Filtering
- SAC: `RANK_ID IN ('13', '18')` | SMAC: `ranks.name IN ('Master', 'Chief Engineer')`

### 9. Appraisal Feedback Structure
- SAC: JSON array on `appraisals.FEEDBACK`, exploded with LATERAL VIEW
- SMAC: separate rows in `seafarer_appraisal_forms` (joined via `appraisal_id`)
- SAC `templateName` → SMAC `appraisal_stages.name` (via `stage_id`)
- SAC `rating` → SMAC `seafarer_appraisal_forms.average_score`

### 10. Inactive Seafarer Identification
- SAC: `SEAFARER_REMARKS.profile_remark[0].remark_type = 'INACTIVE'`
- SMAC: `seafarer_remarks` (crewing_shore) with `profile_remark_type_id` = `4bf24d17-381a-429b-83aa-849cbf5279d6`
- Filter currently inactive: `seafarers.profile_status_id = '01993624-9d27-7fa6-8387-ba5a60c6b128'`

### 11. Appraisal Stage Mapping
| SAC templateName | SMAC stage_name |
|---|---|
| Crewing Superintendent Feedback | Crewing Superintendent Feedback |
| Marine Superintendent Feedback | Marine Superintendent Feedback |
| Technical Superintendent Feedback | Technical Superintendent Feedback |
| Appraisee feedback | Appraisee Acknowledgement |
| Marine Manager Feedback | Marine Manager Feedback |
| Technical Manager Feedback | Technical Manager Feedback |

---

## Key Static UUIDs

| Entity | UUID |
|--------|------|
| INACTIVE profile_status | `01993624-9d27-7fa6-8387-ba5a60c6b128` |
| ACTIVE profile_status | `01993624-445a-7d2e-a9fe-1c2731b37803` |
| DEACTIVATION remark_type | `4bf24d17-381a-429b-83aa-849cbf5279d6` |
| ACTIVATION remark_type | `cbc7d23f-ab5d-4224-81e0-22cce334a5cc` |

---

## Common SQL Patterns

### CREATE TABLE Template
```sql
CREATE OR REPLACE TABLE reporting_layer.smac_prod.<table_name>
TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.minReaderVersion' = '2',
  'delta.minWriterVersion' = '5'
)
AS
SELECT ...
```

### Name Extraction from audit_info
```sql
REGEXP_EXTRACT(get_json_object(audit_info, '$.notes'), 'Created by:\\s*(?:AHOY-)?([^;-]+)', 1) AS Initiated_by
```

### Appraiser Name from Forms
```sql
REGEXP_REPLACE(COALESCE(get_json_object(f.audit_info, '$.notes'), ''), '^Appraiser:\\s*', '') AS appraiser_name
```

### Feedback Comments Extraction
```sql
NULLIF(array_join(regexp_extract_all(COALESCE(get_json_object(f.submission_data, '$.data'), ''), '"[^"]*[Rr]emarks?"\\s*:\\s*"([^"]+)"', 1), '; '), '') AS FEEDBACK_COMMENTS
```

### Performance Rating
```sql
ROUND(AVG(f.average_score), 2) AS performance_rating
-- Filter: f.average_score > 0 AND ap.appraisal_status = 'closed'
```

---

## Completed Migrations

| # | Table | SAC Rows | SMAC Rows | Ratio |
|---|-------|----------|-----------|-------|
| 1 | `revised_base_view` | 6,838,743 | 3,190,731 | 46.7% (SAC has deeper history) |
| 2 | `appraisals_data` | 144,848 | 142,300 | 98.2% |
| 3 | `revised_relief_view` | 20,724 | 20,769 | 100.2% |
| 4 | `planner_view` | 78,177 | 78,604 | 100.5% |
| 5 | `add_digital_appraisal_view` | 26,485 | 28,706 | 108% |
| 6 | `appraisal_performance` | 576 | 547 | 95.0% |
| 7 | `digital_appraisal_view` | 2,637 | 2,788 | 105.7% |
| 8 | `inactive_seafarers` | 10,439 | 13,970 | 133.8% |