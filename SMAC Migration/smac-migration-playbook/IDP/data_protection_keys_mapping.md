# Table Mapping: DataProtectionKeys → data_protection_keys

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: DataProtectionKeys (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: data_protection_keys (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| FriendlyName | text | friendly_name | text | TRIM(FriendlyName) | Direct copy |
| Xml | text | xml | text | Direct copy | Direct copy |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (independent table)

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Direct mapping of all columns

