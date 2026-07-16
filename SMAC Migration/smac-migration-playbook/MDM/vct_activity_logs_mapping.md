# Table Mapping: vct_activity_logs

## Overview

Alias for `vessel_details_vct_activity_logs`.

- **Canonical mapping**: [vessel_details_vct_activity_logs_mapping.md](vessel_details_vct_activity_logs_mapping.md)
- **Migration Script**: `04-migration-scripts/master/vessel_details_vct_activity_logs_migration.sql`

## Business Key

- **Composite Key**: (`vct_requests_id`, `user_id`, `created_at`)
- **Source (orchestration)**: VCT Activity Logs (`vessel_details_vct` → `vct_activity_logs`)

## Migration Notes

- Creates activity log entries from approval fields in vessel_details_vct. Creates one entry per approval action: OT approval, OT rejection, final approval, final rejection. References vct_requests via vct_requests_id. Stores approval details in field_json. Maps vct_status based on approval state. Requires vct_requests table to be migrated first.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
