# Table Mapping: UserTenants → user_tenants

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: UserTenants (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_tenants (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | uuid | gen_random_uuid() | Generate new UUID |
| UserId | text | user_id | uuid | Map via migration.table_mappings | FK to users |
| TenantId | text | tenant_id | uuid | Map via migration.table_mappings | FK to tenants (or default) |
| Created | timestamp | created_at | timestamptz | Created AT TIME ZONE 'UTC' | Timezone conversion |
| Updated | timestamp | updated_at | timestamptz | Updated AT TIME ZONE 'UTC' | Timezone conversion |
| - | - | audit_info | jsonb | Build JSON with legacy_id | Audit trail |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **users** - must be migrated before user_tenants

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Generate new UUID for id
- Map UserId and TenantId using migration.table_mappings lookup
- Use default tenant UUID if tenant mapping not found
- Handle timezone conversion for timestamp fields

