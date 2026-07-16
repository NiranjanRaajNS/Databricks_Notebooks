# Agents Table Comparison: Source (SAC) vs Target (SMAC)

## Overview
- **Source Database**: synergy_master.public.agents
- **Target Database**: smac_master_migration.public.agents
- **Comparison Date**: 2026-05-11

---

## 1. Field Mappings Table

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | bigint | id | uuid | Preserve legacy UUID when available, else generate new UUID | ✅ Mapped |
| 2 | uuid | uuid | - | - | Stored in audit_info.legacy_uuid | ⚠️ Moved to audit_info |
| 3 | identifier | varchar | code | varchar(100) | Direct copy with TRIM, fallback to 'UNKNOWN' | ✅ Mapped |
| 4 | name | varchar | name | text | Direct copy with TRIM | ✅ Mapped |
| 5 | address | text | address | jsonb | Convert to JSON object: `{street, raw_address}` | ✅ Mapped |
| 6 | phone | varchar[] | phone_number | varchar(50) | Extract first element from array | ✅ Mapped |
| 7 | email | varchar[] | email | varchar(100) | Extract first element from array | ✅ Mapped |
| 8 | port_id | bigint | country_id | uuid | Map via port lookup (currently NULL in migration) | ⚠️ Not mapped yet |
| 9 | agent_type_id | bigint | agent_type_id | uuid | Map via agent_type_id_mapping | ✅ Mapped |
| 10 | global_agent | boolean | global_agent | boolean | Direct copy with COALESCE to false | ✅ Mapped |
| 11 | status | varchar | status | integer | Map to integer: Active=0, Draft=1, Inactive=2, Deleted=3 | ✅ Mapped |
| 12 | created_at | timestamp | created_at | timestamp | Direct copy with COALESCE to NOW() | ✅ Mapped |
| 13 | updated_at | timestamp | updated_at | timestamp | Direct copy with COALESCE to NOW() | ✅ Mapped |
| 14 | created_by_id | varchar | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 15 | created_by_name | varchar | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 16 | updated_by_id | varchar | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 17 | updated_by_name | varchar | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 18 | agent_sub_type_id | bigint | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 19 | iso_code | varchar[] | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 20 | last_event_date | timestamp | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 21 | change_reason | text | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 22 | status_history | jsonb | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 23 | identity_company_uuid | uuid | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 24 | currency | varchar | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 25 | expense_line_item | jsonb | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |
| 26 | vendor_id | uuid | - | - | Stored in audit_info (NOT currently migrated) | ❌ Missing |

---

## 2. Missing Fields in Source (New Fields in Target)

| # | Target Field (SMAC) | Target Type | Default Value | Notes |
|---|---------------------|-------------|---------------|-------|
| 1 | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New required field for multi-tenancy |
| 2 | version | integer | 1 | New required field |
| 3 | defined_by | integer | 0 (Global) | New required field - integer, not enum |
| 4 | workflow_status | integer | 0 (Draft) | New required field - integer, not enum |
| 5 | description | text | NULL | New optional field (currently set to NULL) |
| 6 | parent_id | uuid | NULL | New optional field (not in migration script) |
| 7 | state_id | uuid | NULL | New optional field (not in migration script) |
| 8 | level | numeric | NULL | New optional field (not in migration script) |
| 9 | tags | text[] | NULL | New optional field (not in migration script) |
| 10 | audit_info | jsonb | JSON object | New field for audit trail and legacy data preservation |

---

## 3. Missing Fields in Target (Source Fields Not Migrated)

### Fields Moved to audit_info (but NOT currently stored)

| # | Source Field | Source Type | Intended Location | Current Status |
|---|--------------|-------------|-------------------|----------------|
| 1 | created_by_id | varchar | audit_info.created_by_id | ❌ NOT migrated |
| 2 | created_by_name | varchar | audit_info.created_by_name | ❌ NOT migrated |
| 3 | updated_by_id | varchar | audit_info.updated_by_id | ❌ NOT migrated |
| 4 | updated_by_name | varchar | audit_info.updated_by_name | ❌ NOT migrated |
| 5 | agent_sub_type_id | bigint | audit_info.agent_sub_type_id | ❌ NOT migrated |
| 6 | iso_code | varchar[] | audit_info.iso_codes | ❌ NOT migrated |
| 7 | last_event_date | timestamp | audit_info.last_event_date | ❌ NOT migrated |
| 8 | change_reason | text | audit_info.change_reason | ❌ NOT migrated |
| 9 | status_history | jsonb | audit_info.status_history | ❌ NOT migrated |
| 10 | identity_company_uuid | uuid | audit_info.identity_company_uuid | ❌ NOT migrated |
| 11 | currency | varchar | audit_info.currency | ❌ NOT migrated |
| 12 | expense_line_item | jsonb | audit_info.expense_line_item | ❌ NOT migrated |
| 13 | vendor_id | uuid | audit_info.vendor_id | ❌ NOT migrated |

### Fields Stored in audit_info (currently migrated)

| # | Source Field | Source Type | Current Location | Status |
|---|--------------|-------------|------------------|--------|
| 1 | uuid | uuid | audit_info.legacy_uuid | ✅ Migrated |
| 2 | id | bigint | audit_info.legacy_id | ✅ Migrated |

---

## 4. Data Transformation Summary

### Direct Mappings (No Transformation)
- `name` → `name` (with TRIM)
- `global_agent` → `global_agent` (with COALESCE to false)
- `created_at` → `created_at` (with COALESCE to NOW())
- `updated_at` → `updated_at` (with COALESCE to NOW())

### Type Conversions
- `id` (bigint) → `id` (uuid): Preserve legacy UUID when available
- `identifier` (varchar) → `code` (varchar(100)): Field rename
- `status` (varchar) → `status` (integer): String to integer mapping
- `address` (text) → `address` (jsonb): Text to JSON object

### Array to Single Value
- `phone[]` → `phone_number`: Extract first element
- `email[]` → `email`: Extract first element

### Foreign Key Mappings
- `port_id` (bigint) → `country_id` (uuid): **NOT IMPLEMENTED** (currently NULL)
- `agent_type_id` (bigint) → `agent_type_id` (uuid): Mapped via agent_type_id_mapping

### New Fields Added
- `tenant_id`: Default tenant UUID
- `version`: Default to 1
- `defined_by`: Default to 0 (Global)
- `workflow_status`: Default to 0 (Draft)
- `description`: Set to NULL
- `audit_info`: JSONB object with legacy metadata

---

## 5. Issues and Recommendations

### Critical Issues

1. **Missing audit_info fields**: The migration script does NOT currently store the following fields in audit_info:
   - created_by_id, created_by_name
   - updated_by_id, updated_by_name
   - agent_sub_type_id
   - iso_code
   - last_event_date
   - change_reason
   - status_history
   - identity_company_uuid
   - currency
   - expense_line_item
   - vendor_id

   **Recommendation**: Update the migration script to include these fields in the audit_info JSONB object.

2. **port_id not mapped**: The `port_id` field is not being mapped to `country_id` (currently set to NULL).

   **Recommendation**: Implement port-to-country mapping logic similar to how agent_type_id is mapped.

### Missing Target Fields

The following target fields exist in the SMAC schema but are NOT included in the migration script:
- `parent_id` (uuid)
- `state_id` (uuid)
- `level` (numeric)
- `tags` (text[])

**Recommendation**: Determine if these fields should be populated during migration or left as NULL.

---

## 6. Current audit_info Structure

```json
{
  "legacy_id": "<bigint id as text>",
  "legacy_uuid": "<uuid as text>",
  "migrated_at": "<timestamp>",
  "migration_source": "synergy_master"
}
```

### Expected audit_info Structure (per mapping document)

```json
{
  "legacy_id": "<bigint id as text>",
  "legacy_uuid": "<uuid as text>",
  "created_by_id": "<varchar>",
  "created_by_name": "<varchar>",
  "updated_by_id": "<varchar>",
  "updated_by_name": "<varchar>",
  "agent_sub_type_id": "<bigint>",
  "iso_codes": "<varchar[]>",
  "last_event_date": "<timestamp>",
  "change_reason": "<text>",
  "status_history": "<jsonb>",
  "identity_company_uuid": "<uuid>",
  "currency": "<varchar>",
  "expense_line_item": "<jsonb>",
  "vendor_id": "<uuid>",
  "migrated_at": "<timestamp>",
  "migration_source": "synergy_master"
}
```

---

## 7. Summary Statistics

| Category | Count |
|----------|-------|
| **Total Source Fields** | 26 |
| **Total Target Fields** | 19 |
| **Fields Directly Mapped** | 13 |
| **Fields Moved to audit_info** | 13 (only 2 currently migrated) |
| **New Fields in Target** | 10 |
| **Fields Missing from Migration** | 11 (should be in audit_info) |
| **Fields Not Implemented** | 1 (port_id → country_id) |

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-11-18 | Migration Team | Initial comparison created based on migration script and mapping document |

