# Table Mapping: ApiScopeClaims → api_scope_claims

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiScopeClaims (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_scope_claims (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Type | varchar(200) | claim_type | varchar(200) | TRIM(type) | Maps to claim_type in target |
| ScopeId | integer | scope_id | integer | Map via migration.table_mappings | FK to api_scopes |

## Foreign Key Dependencies
- **scope_id**: References `api_scopes.id` (must be migrated first)

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ScopeId to scope_id using migration.table_mappings lookup
- Only migrate records where scope mapping exists

