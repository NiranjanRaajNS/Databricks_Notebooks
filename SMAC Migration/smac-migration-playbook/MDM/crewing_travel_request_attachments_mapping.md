# Table Mapping: crewing_travel_request_attachments

## Overview

Alias for `crewing_travel_request_attachments`.

- **Canonical mapping**: [crewing_travel_request_attachments_mapping.md](../crewing/crewing_travel_request_attachments_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/crewing_travel_request_attachments_migration.sql`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Crewing Travel Request Attachments (`travel_documents` → `crewing_travel_request_attachments`)

## Migration Notes

- Migrates travel_documents to crewing_travel_request_attachments preserving UUID. Maps relief_id to travel_request_id via crewing_travel_requests. Uses default workflow_status_id from workflow_status table.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
