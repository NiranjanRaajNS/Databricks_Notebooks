# Table Mapping: UserTokens → user_tokens

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: UserTokens (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_tokens (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | uuid | gen_random_uuid() | Generate new UUID |
| UserId | text | user_id | uuid | Map via migration.table_mappings | FK to users |
| LoginProvider | text | login_provider | text | TRIM(LoginProvider) | Required |
| Name | text | name | text | TRIM(Name) | Required |
| Value | text | value | text | TRIM(Value) | Required |
| Created | timestamp | created_at | timestamptz | Created AT TIME ZONE 'UTC' | Timezone conversion |
| Updated | timestamp | updated_at | timestamptz | Updated AT TIME ZONE 'UTC' | Timezone conversion |
| - | - | audit_info | jsonb | Build JSON with legacy_id | Audit trail |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **users** - must be migrated before user_tokens

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Generate new UUID for id
- Map UserId using migration.table_mappings lookup
- Use default UUID if user mapping not found
- Handle timezone conversion for timestamp fields

