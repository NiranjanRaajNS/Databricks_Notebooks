# Table Mapping: seafarer_profile

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarers (columns split into seafarer_profile)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_profile
- **Migration Priority**: HIGH
- **Migration Approach**: Combined migration with seafarers table (same transaction)
- **Estimated Row Count**: Same as seafarers table (one-to-one relationship)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | bigint | seafarer_id | uuid | From migrated seafarers.id | Foreign key to seafarers table |
| 2 | - | - | id | uuid | gen_random_uuid() | Primary key, generated UUID |
| 3 | place_of_birth | text | place_of_birth | text | TRIM(place_of_birth) | Direct copy, trim whitespace |
| 4 | religion_id | bigint | religion_id | uuid | Map via religion_id_mapping | FK to religions (from synergy_master) |
| 5 | marital_status | text | marital_statu_id | uuid | Map via marital_status_id_mapping (by name) | FK to marital_statuses (from smac_master_migration), note: typo in column name |
| 6 | blood_group | text | blood_group_id | uuid | Map via blood_group_id_mapping (by name) | FK to bloodgroups (from smac_master_migration) |
| 7 | height | double precision | height | numeric(5,2) | Clamp to range -999.99 to 999.99 | Clamped to numeric(5,2) range, original stored in audit_info |
| 8 | weight | double precision | weight | numeric(5,2) | Clamp to range -999.99 to 999.99 | Clamped to numeric(5,2) range, original stored in audit_info |
| 9 | anniversary_date | timestamp | anniversary_date | timestamp | Direct copy | Date field |
| 10 | - | - | sap_bp_number | varchar(50) | NULL | New column, not in source |
| 11 | e_reg_no | text | e_reg_no | text | TRIM(e_reg_no) | Direct copy, trim whitespace |
| 12 | sss_no | text | sss_no | text | TRIM(sss_no) | Direct copy, trim whitespace |
| 13 | hdmf_no | text | hdmf_no | text | TRIM(hdmf_no) | Direct copy, trim whitespace |
| 14 | srn_no | text | srn_no | text | TRIM(srn_no) | Direct copy, trim whitespace |
| 15 | hair_color | text | hair_color | text | TRIM(hair_color) | Direct copy, trim whitespace |
| 16 | eye_color | text | eye_color | text | TRIM(eye_color) | Direct copy, trim whitespace |
| 17 | - | - | working_gear | jsonb | NULL | New column, not in source |
| 18 | english_language_proficiency | jsonb | language_proficiency | jsonb | COALESCE(english_language_proficiency, '{}'::jsonb) | Renamed column, default to '{}' |
| 19 | phil_health_id | text | philhealth_id | text | TRIM(phil_health_id) | Renamed (underscore removed) |
| 20 | - | - | tenant_id | uuid | DEFAULT_TENANT_ID | New required field (see constants.sql) |
| 21 | - | - | alternative_address | jsonb | '{}'::jsonb | New required field, default empty JSON |
| 22 | - | - | primary_address | jsonb | '{}'::jsonb | New required field, default empty JSON |
| 23 | - | - | status | text | '' | New required field, default empty string |
| 24 | - | - | availability_requested | boolean | false | New required field, default false |
| 25 | - | - | metadata | jsonb | '{}'::jsonb | New required field, default empty JSON |
| 26 | created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Timestamp with default |
| 27 | updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Timestamp with default |
| 28 | - | - | audit_info | jsonb | Build JSON with legacy data | Standard SMAC audit_info structure |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **seafarers**: Required - seafarer_profile.seafarer_id references seafarers.id
- **religions** (from synergy_master) - Required for religion_id mapping
- **marital_statuses** (from smac_master_migration) - Required for marital_statu_id mapping (by name)
- **bloodgroups** (from smac_master_migration) - Required for blood_group_id mapping (by name)

### Dependents (migrate after this table)
- None (this is a detail table)

## Data Transformation Rules

### Foreign Key Resolution
- **seafarer_id**: Uses `inserted_seafarers` temp table from seafarers migration
- **religion_id**: Mapped via `religion_id_mapping` (by ID)
- **marital_statu_id**: Mapped via `marital_status_id_mapping` (by name, case-insensitive)
- **blood_group_id**: Mapped via `blood_group_id_mapping` (by name, case-insensitive)

### Height and Weight Clamping
- Source: `double precision` (unlimited range)
- Target: `numeric(5,2)` (range: -999.99 to 999.99)
- Values exceeding range are clamped to max/min
- Original values stored in `audit_info->>'original_height'` and `audit_info->>'original_weight'`

### String Trimming
All text fields are trimmed:
- `TRIM(place_of_birth)`
- `TRIM(e_reg_no)`
- `TRIM(sss_no)`
- `TRIM(hdmf_no)`
- `TRIM(srn_no)`
- `TRIM(hair_color)`
- `TRIM(eye_color)`
- `TRIM(phil_health_id)`

### NULL Handling
- All profile columns are optional (can be NULL)
- Use COALESCE for timestamps with NOW() fallback
- JSONB fields default to '{}' if NULL

### Audit Information
Store the following in `audit_info` JSONB:
- `legacy_seafarer_id`: Source seafarer id (bigint as text)
- `original_height`: Original height value (may exceed numeric(5,2) range)
- `original_weight`: Original weight value (may exceed numeric(5,2) range)
- `migrated_at`: Migration timestamp
- `migration_source`: 'synergy_seafarer'

## Migration Strategy

### Combined Migration Approach
- Migrated together with `seafarers` and `seafarer_service_records` in the same transaction
- Uses `inserted_seafarers` temp table to capture inserted seafarer IDs
- Joins with legacy data using `legacy_data.id::text = ins.legacy_id`
- Single pass through source data
- Atomic operation (all three tables updated together)

### Implementation Pattern
```sql
FROM inserted_seafarers ins
JOIN dblink('synergy_seafarer', 'SELECT ... FROM public.seafarers') AS legacy_data(...)
    ON legacy_data.id::text = ins.legacy_id
LEFT JOIN religion_id_mapping religion_map ON religion_map.source_id = legacy_data.religion_id
LEFT JOIN marital_status_id_mapping marital_status_map ON UPPER(TRIM(...)) = UPPER(TRIM(...))
LEFT JOIN blood_group_id_mapping blood_group_map ON UPPER(TRIM(...)) = UPPER(TRIM(...))
```

## Validation Checklist

- [ ] Row count matches seafarers table (one-to-one relationship)
- [ ] All seafarer_id references exist in seafarers table (FK integrity)
- [ ] No duplicate seafarer_id values
- [ ] String fields are properly trimmed
- [ ] Height and weight values are within numeric(5,2) range (or clamped)
- [ ] Original height/weight values stored in audit_info
- [ ] Date fields are valid (no future dates for anniversary_date)
- [ ] JSONB fields default to '{}' when NULL
- [ ] Sample data comparison between legacy and new databases

## Notes

- This is a one-to-one relationship with seafarers table
- Combined migration ensures data consistency
- All profile columns are optional (can be NULL)
- Migration happens in the same transaction as seafarers migration
- Height and weight values are clamped to numeric(5,2) range, originals preserved in audit_info
- Column name typo: `marital_statu_id` (should be `marital_status_id` but kept as-is for compatibility)

