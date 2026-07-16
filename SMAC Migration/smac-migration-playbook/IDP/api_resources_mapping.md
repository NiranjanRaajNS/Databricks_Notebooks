# Table Mapping: ApiResources → api_resources

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiResources (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_resources (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Enabled | boolean | enabled | boolean | COALESCE(enabled, false) | Direct copy |
| Name | varchar(200) | name | varchar(200) | TRIM(name) | Required, business key |
| DisplayName | varchar(200) | display_name | varchar(200) | TRIM(display_name) | Direct copy |
| Description | varchar(1000) | description | varchar(1000) | TRIM(description) | Direct copy |
| AllowedAccessTokenSigningAlgorithms | varchar(100) | allowed_access_token_signing_algorithms | varchar(100) | TRIM() | Direct copy |
| ShowInDiscoveryDocument | boolean | show_in_discovery_document | boolean | COALESCE(..., true) | Direct copy |
| Created | timestamp without time zone | created_at | timestamp with time zone | AT TIME ZONE 'UTC', COALESCE with NOW() | NOT NULL, timezone conversion |
| Updated | timestamp without time zone | updated_at | timestamp with time zone | AT TIME ZONE 'UTC' | Nullable, timezone conversion |
| LastAccessed | timestamp without time zone | last_accessed | timestamp with time zone | AT TIME ZONE 'UTC' | Nullable, timezone conversion |
| NonEditable | boolean | non_editable | boolean | COALESCE(..., false) | Direct copy |

## Foreign Key Dependencies
- None (standalone table)

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Filter records where Name IS NOT NULL AND TRIM(Name) != ''

