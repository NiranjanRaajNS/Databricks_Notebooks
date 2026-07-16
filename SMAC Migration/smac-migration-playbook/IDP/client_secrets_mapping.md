# Table Mapping: ClientSecrets → client_secrets

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ClientSecrets (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: client_secrets (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| ClientId | integer | client_id | integer | Map via migration.table_mappings | FK to clients |
| Description | varchar | description | varchar | TRIM(Description) | Direct copy |
| Value | varchar | value | varchar | TRIM(Value) | Direct copy |
| Expiration | timestamp | expiration | timestamptz | Expiration AT TIME ZONE 'UTC' | Timezone conversion, nullable |
| Type | varchar | type | varchar | TRIM(Type) | Direct copy |
| Created | timestamp | created_at | timestamptz | COALESCE(Created AT TIME ZONE 'UTC', NOW()) | Timezone conversion, NOT NULL |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **clients** - must be migrated before client_secrets

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ClientId to client_id using migration.table_mappings lookup
- Only migrate records where client mapping exists
- Handle timezone conversion for timestamp fields

