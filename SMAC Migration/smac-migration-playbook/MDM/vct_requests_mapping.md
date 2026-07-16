# Table Mapping: vct_requests

## Overview

Alias for `vessel_details_vct`.

- **Canonical mapping**: [vessel_details_vct_mapping.md](vessel_details_vct_mapping.md)
- **Migration Script**: `04-migration-scripts/master/vessel_details_vct_migration.sql`

## Business Key

- **Composite Key**: (`requester_id`, `created_at`)
- **Source (orchestration)**: VCT Requests (`vessel_details_vct` → `vct_requests`)

## Migration Notes

- Migrates vessel_details_vct to vct_requests. Preserves identifier UUID as id when available. Stores all vessel details and vessel_particulars_vct fields in field_json JSONB. Maps vct_status from approval fields: Draft=0, PendingApproval=1, Approved=2, Rejected=3. Maps requester_id and reporting_officer_id directly. Maps status (varchar) to status (integer) with deleted_at precedence. vessel_id and vessel_revision_id are nullable and may be NULL if mapping cannot be determined.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
