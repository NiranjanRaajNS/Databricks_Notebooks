# Table Mapping: UserServiceType → user_service_type

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: UserServiceType (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_service_type (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | uuid | gen_random_uuid() | Generate new UUID |
| UserId | text | user_id | uuid | Map via migration.table_mappings | FK to users |
| ServiceTypeId | text | service_type_id | uuid | Map via migration.table_mappings | FK to service_types |
| Created | timestamp | created_at | timestamptz | Created AT TIME ZONE 'UTC' | Timezone conversion |
| Updated | timestamp | updated_at | timestamptz | Updated AT TIME ZONE 'UTC' | Timezone conversion |
| - | - | audit_info | jsonb | Build JSON with legacy_id | Audit trail |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **users** - must be migrated before user_service_type
- **service_types** - must be migrated before user_service_type

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Generate new UUID for id
- Map UserId and ServiceTypeId using migration.table_mappings lookup
- Use default UUID if mapping not found
- Handle timezone conversion for timestamp fields

