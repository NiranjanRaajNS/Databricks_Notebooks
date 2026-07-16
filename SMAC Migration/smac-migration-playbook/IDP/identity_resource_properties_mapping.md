# Table Mapping: IdentityResourceProperties → identity_resource_properties

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: IdentityResourceProperties (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: identity_resource_properties (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| IdentityResourceId | integer | identity_resource_id | integer | Map via migration.table_mappings | FK to identity_resources |
| Key | varchar | key | varchar | TRIM(Key) | Required |
| Value | varchar | value | varchar | TRIM(Value) | Required |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **identity_resources** - must be migrated before identity_resource_properties

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map IdentityResourceId to identity_resource_id using migration.table_mappings lookup
- Only migrate records where identity_resource mapping exists

