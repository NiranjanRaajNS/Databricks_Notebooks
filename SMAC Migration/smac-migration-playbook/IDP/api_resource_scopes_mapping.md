# Table Mapping: ApiResourceScopes → api_resource_scopes

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiResourceScopes (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_resource_scopes (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Scope | varchar(200) | scope | varchar(200) | TRIM(scope) | NOT NULL, stores scope name as text (not FK) |
| ApiResourceId | integer | api_resource_id | integer | Map via migration.table_mappings | FK to api_resources |

## Foreign Key Dependencies
- **api_resource_id**: References `api_resources.id` (must be migrated first)
- **Note**: `scope` is stored as varchar text, not as FK to api_scopes table

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ApiResourceId to api_resource_id using migration.table_mappings lookup
- Copy Scope directly as varchar (TRIM whitespace)
- Only migrate records where api_resource mapping exists and scope is not empty

