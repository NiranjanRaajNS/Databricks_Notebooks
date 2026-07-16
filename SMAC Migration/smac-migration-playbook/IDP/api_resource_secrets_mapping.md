# Table Mapping: ApiResourceSecrets → api_resource_secrets

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiResourceSecrets (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_resource_secrets (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| ApiResourceId | integer | api_resource_id | integer | Map via migration.table_mappings | FK to api_resources (must be migrated first) |
| Description | varchar(1000) | description | varchar(1000) | TRIM(description) | Nullable, direct copy |
| Value | varchar(4000) | value | varchar(4000) | TRIM(value) | NOT NULL, direct copy |
| Expiration | timestamp without time zone | expiration | timestamp with time zone | AT TIME ZONE 'UTC' | Nullable, timezone conversion |
| Type | varchar(250) | type | varchar(250) | TRIM(type) | NOT NULL, direct copy |
| Created | timestamp without time zone | created_at | timestamp with time zone | AT TIME ZONE 'UTC', COALESCE with NOW() | NOT NULL, timezone conversion |

## Foreign Key Dependencies
- **api_resource_id**: References `api_resources.id` (must be migrated first)

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Map ApiResourceId to api_resource_id using migration.table_mappings lookup
- Only migrate records where api_resource mapping exists

