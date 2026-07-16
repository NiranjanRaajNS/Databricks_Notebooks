# Table Mapping: ApiScopeProperties → api_scope_properties

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiScopeProperties (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_scope_properties (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Key | varchar(250) | key | varchar(250) | TRIM(key) | Direct copy |
| Value | varchar(2000) | value | varchar(2000) | TRIM(value) | Direct copy |
| ScopeId | integer | scope_id | integer | Map via migration.table_mappings | FK to api_scopes |

## Foreign Key Dependencies
- **scope_id**: References `api_scopes.id` (must be migrated first)

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ScopeId to scope_id using migration.table_mappings lookup
- Only migrate records where scope mapping exists

