# Table Mapping: IdentityResources → identity_resources

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: IdentityResources (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: identity_resources (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| Enabled | boolean | enabled | boolean | COALESCE(Enabled, false) | Direct copy |
| Name | varchar | name | varchar | TRIM(Name) | Required |
| DisplayName | varchar | display_name | varchar | TRIM(DisplayName) | Direct copy |
| Description | varchar | description | varchar | TRIM(Description) | Direct copy |
| Required | boolean | required | boolean | COALESCE(Required, false) | Direct copy |
| Emphasize | boolean | emphasize | boolean | COALESCE(Emphasize, false) | Direct copy |
| ShowInDiscoveryDocument | boolean | show_in_discovery_document | boolean | COALESCE(ShowInDiscoveryDocument, true) | Direct copy |
| Created | timestamp | created_at | timestamptz | COALESCE(Created AT TIME ZONE 'UTC', NOW()) | Timezone conversion |
| Updated | timestamp | updated_at | timestamptz | Updated AT TIME ZONE 'UTC' | Timezone conversion |
| NonEditable | boolean | non_editable | boolean | COALESCE(NonEditable, false) | Direct copy |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table for identity resources)

### Dependents (migrate after this table)
- **identity_resource_claims** - references identity_resources.id
- **identity_resource_properties** - references identity_resources.id

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Handle timezone conversion for timestamp fields
- Filter out records where Name is NULL or empty

