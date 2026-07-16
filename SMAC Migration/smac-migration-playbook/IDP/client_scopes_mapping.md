# Table Mapping: ClientScopes → client_scopes

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ClientScopes (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: client_scopes (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| ClientId | integer | client_id | integer | Map via migration.table_mappings | FK to clients |
| Scope | varchar | scope | varchar | TRIM(Scope) | Direct copy |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **clients** - must be migrated before client_scopes

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ClientId to client_id using migration.table_mappings lookup
- Only migrate records where client mapping exists and scope is not NULL/empty

