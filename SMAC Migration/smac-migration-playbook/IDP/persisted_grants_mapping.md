# Table Mapping: PersistedGrants → persisted_grants

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: PersistedGrants (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: persisted_grants (lowercase)
- **Migration Priority**: MEDIUM
- **Estimated Row Count**: To be determined via discovery script

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | Key | text | key | text | TRIM(Key) | Primary key, direct copy |
| 2 | Type | text | type | text | TRIM(Type) | Direct copy |
| 3 | SubjectId | text | subject_id | text | TRIM(SubjectId) | Direct copy |
| 4 | SessionId | text | session_id | text | TRIM(SessionId) | Direct copy |
| 5 | ClientId | text | client_id | text | TRIM(ClientId) | Direct copy |
| 6 | Description | text | description | text | TRIM(Description) | Direct copy |
| 7 | CreationTime | timestamp | creation_time | timestamptz | CreationTime AT TIME ZONE 'UTC' | Convert to timestamptz |
| 8 | Expiration | timestamp | expiration | timestamptz | Expiration AT TIME ZONE 'UTC' | Convert to timestamptz, nullable |
| 9 | ConsumedTime | timestamp | consumed_time | timestamptz | ConsumedTime AT TIME ZONE 'UTC' | Convert to timestamptz, nullable |
| 10 | Data | text | data | text | TRIM(Data) | Direct copy |

## ID Field Handling

- **Source**: Uses "Key" as primary key (text)
- **Target**: Uses "key" as primary key (text)
- **Mapping**: Uses key as source_id in mapping table (generates UUID for target_id)

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None

### Dependents (migrate after this table)
- None

## Data Transformation Rules

### 1. Timezone Conversion
- Convert all timestamp columns to timestamptz using `AT TIME ZONE 'UTC'`
- Handle NULL values for nullable timestamp columns

### 2. String Trimming
- Apply TRIM() to all text columns

## Validation Checklist

- [ ] Row count matches legacy count
- [ ] All required fields (key, type, client_id, data, creation_time) are NOT NULL
- [ ] No duplicate keys
- [ ] Timestamps converted correctly to timestamptz
- [ ] Mapping records created correctly

## Notes

- This table stores OAuth2/OpenID Connect persisted grants
- Primary key is "key" (text), not UUID
- No foreign key dependencies

