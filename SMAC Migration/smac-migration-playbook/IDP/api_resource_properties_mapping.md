# Table Mapping: ApiResourceProperties → api_resource_properties

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiResourceProperties (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_resource_properties (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Key | varchar | key | varchar | TRIM(key) | Direct copy |
| Value | varchar | value | varchar | TRIM(value) | Direct copy |
| ApiResourceId | integer | api_resource_id | integer | Map via migration.table_mappings | FK to api_resources |

## Foreign Key Dependencies
- **api_resource_id**: References `api_resources.id` (must be migrated first)

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ApiResourceId to api_resource_id using migration.table_mappings lookup
- Only migrate records where api_resource mapping exists

