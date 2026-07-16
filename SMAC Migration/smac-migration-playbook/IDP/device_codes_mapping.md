# Table Mapping: DeviceCodes → device_codes

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: DeviceCodes (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: device_codes (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| UserCode | varchar | user_code | varchar | TRIM(UserCode) | Primary key |
| DeviceCode | varchar | device_code | varchar | TRIM(DeviceCode) | Required |
| SubjectId | varchar | subject_id | varchar | TRIM(SubjectId) | Direct copy |
| ClientId | varchar | client_id | varchar | TRIM(ClientId) | Required |
| CreationTime | timestamp | creation_time | timestamptz | CreationTime AT TIME ZONE 'UTC' | Timezone conversion |
| Expiration | timestamp | expiration | timestamptz | Expiration AT TIME ZONE 'UTC' | Timezone conversion |
| Data | varchar | data | varchar | TRIM(Data) | Required |
| SessionId | varchar | session_id | varchar | TRIM(SessionId) | Direct copy |
| Description | varchar | description | varchar | TRIM(Description) | Direct copy |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (independent table)

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use UserCode as primary key (no ID generation needed)
- Handle timezone conversion for timestamp fields
- Filter out records where UserCode is NULL or empty

