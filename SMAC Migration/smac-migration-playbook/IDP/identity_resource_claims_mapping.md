# Table Mapping: IdentityResourceClaims → identity_resource_claims

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: IdentityResourceClaims (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: identity_resource_claims (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| IdentityResourceId | integer | identity_resource_id | integer | Map via migration.table_mappings | FK to identity_resources |
| Type | varchar | claim_type | varchar | TRIM(Type) | Maps to claim_type column |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **identity_resources** - must be migrated before identity_resource_claims

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map IdentityResourceId to identity_resource_id using migration.table_mappings lookup
- Only migrate records where identity_resource mapping exists
- Map Type column to claim_type (similar to api_resource_claims pattern)

