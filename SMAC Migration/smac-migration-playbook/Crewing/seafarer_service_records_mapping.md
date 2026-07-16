# Table Mapping: seafarer_service_records

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarers (columns split into seafarer_service_records)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_service_records
- **Migration Priority**: HIGH
- **Migration Approach**: Combined migration with seafarers table (same transaction)
- **Estimated Row Count**: Same as seafarers table (one-to-one relationship)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | bigint | seafarer_id | uuid | From migrated seafarers.id | Foreign key to seafarers table |
| 2 | - | - | id | uuid | gen_random_uuid() | Primary key, generated UUID |
| 3 | is_to_be_promoted | boolean | is_to_be_promoted | boolean | COALESCE(is_to_be_promoted, false) | NOT NULL, default false |
| 4 | proposed_rank_id | uuid | proposed_rank_id | uuid | Map via rank_uuid_mapping | FK to ranks (from smac_master_migration), UUID preserved |
| 5 | synergy_joining_date | timestamp | joining_date | timestamp | Direct copy | Renamed column |
| 6 | suitability | text[] | vessel_suitability | jsonb | Convert text[] to jsonb, default '{}' | Array converted to JSONB |
| 7 | experience_summary | jsonb | experience_summary | jsonb | COALESCE(experience_summary, '{}'::jsonb) | Default to '{}' if NULL |
| 8 | proposed_vessel_id | bigint | proposed_vessel_id | uuid | Map via vessel_uuid_mapping | FK to vessels (from synergy_vessel) |
| 9 | proposed_vessel_category | uuid | proposed_vessel_category | uuid | Direct copy | Direct UUID mapping |
| 10 | last_sailed_vessel_imo | text | last_sailed_vessel_imo | text | TRIM(last_sailed_vessel_imo) | Direct copy, trim whitespace |
| 11 | synergy_joining_place | text | joining_place_id | uuid | Map via joining_place_id_mapping (by name) | FK to joining_places (from smac_master_migration) |
| 12 | last_engagement_company_name | text | last_contract_company_name | text | TRIM(last_engagement_company_name) | Renamed column |
| 13 | deleted_at | timestamp | deleted_at | timestamp | Direct copy | Soft delete timestamp |
| 14 | - | - | tenant_id | uuid | DEFAULT_TENANT_ID | New required field (see constants.sql) |
| 15 | - | - | archived_at | timestamp | NULL | New column, not in source |
| 16 | - | - | status | text | '' | New required field, default empty string |
| 17 | created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Timestamp with default |
| 18 | updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Timestamp with default |
| 19 | - | - | audit_info | jsonb | Build JSON with legacy data | Standard SMAC audit_info structure |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **seafarers**: Required - seafarer_service_records.seafarer_id references seafarers.id
- **ranks** (from smac_master_migration) - Required for proposed_rank_id mapping (UUID preserved)
- **vessels** (from synergy_vessel) - Required for proposed_vessel_id mapping
- **joining_places** (from smac_master_migration) - Required for joining_place_id mapping (by name)

### Dependents (migrate after this table)
- None (this is a detail table)

## Data Transformation Rules

### Foreign Key Resolution
- **seafarer_id**: Uses `inserted_seafarers` temp table from seafarers migration
- **proposed_rank_id**: Mapped via `rank_uuid_mapping` (UUID preserved, matches id in smac_master_migration.ranks)
- **proposed_vessel_id**: Mapped via `vessel_uuid_mapping` (from synergy_vessel)
- **joining_place_id**: Mapped via `joining_place_id_mapping` (by name, case-insensitive)

### Array to JSONB Conversion
- Source: `suitability` is `text[]` (array)
- Target: `vessel_suitability` is `jsonb`
- Conversion: `to_jsonb(suitability)` if array has elements, otherwise `'{}'::jsonb`
- Handles NULL arrays and empty arrays

### String Trimming
- `TRIM(last_sailed_vessel_imo)`
- `TRIM(last_engagement_company_name)`

### NULL Handling
- Use COALESCE for boolean fields with false default
- Use COALESCE for JSONB fields with '{}' default
- Use COALESCE for timestamps with NOW() fallback

### Audit Information
Store the following in `audit_info` JSONB:
- `legacy_seafarer_id`: Source seafarer id (bigint as text)
- `migrated_at`: Migration timestamp
- `migration_source`: 'synergy_seafarer'

## Migration Strategy

### Combined Migration Approach
- Migrated together with `seafarers` and `seafarer_profile` in the same transaction
- Uses `inserted_seafarers` temp table to capture inserted seafarer IDs
- Joins with legacy data using `legacy_data.id::text = ins.legacy_id`
- Single pass through source data
- Atomic operation (all three tables updated together)

### Implementation Pattern
```sql
FROM inserted_seafarers ins
JOIN dblink('synergy_seafarer', 'SELECT ... FROM public.seafarers') AS legacy_data(...)
    ON legacy_data.id::text = ins.legacy_id
LEFT JOIN vessel_uuid_mapping vessel_uuid_map2 ON vessel_uuid_map2.source_id = legacy_data.proposed_vessel_id
LEFT JOIN rank_uuid_mapping proposed_rank_map ON proposed_rank_map.source_uuid = legacy_data.proposed_rank_id
LEFT JOIN joining_place_id_mapping joining_place_map 
    ON UPPER(TRIM(...)) = UPPER(TRIM(...))
```

## Validation Checklist

- [ ] Row count matches seafarers table (one-to-one relationship)
- [ ] All seafarer_id references exist in seafarers table (FK integrity)
- [ ] No duplicate seafarer_id values
- [ ] String fields are properly trimmed
- [ ] Array to JSONB conversion correct (suitability → vessel_suitability)
- [ ] JSONB fields default to '{}' when NULL
- [ ] Date fields are valid (no future dates for joining_date)
- [ ] UUID fields properly mapped (proposed_rank_id, proposed_vessel_category)
- [ ] Sample data comparison between legacy and new databases

## Notes

- This is a one-to-one relationship with seafarers table
- Combined migration ensures data consistency
- All service record columns are optional (can be NULL) except is_to_be_promoted
- Migration happens in the same transaction as seafarers migration
- Array conversion: `suitability` text[] → `vessel_suitability` jsonb
- Proposed rank uses UUID mapping (preserved from legacy UUID column)
- Joining place mapped by name (case-insensitive match)

