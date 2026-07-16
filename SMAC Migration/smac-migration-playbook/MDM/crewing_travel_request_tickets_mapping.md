# Table Mapping: crewing_travel_request_tickets

## Overview

Alias for `crewing_travel_request_tickets`.

- **Canonical mapping**: [crewing_travel_request_tickets_mapping.md](../crewing/crewing_travel_request_tickets_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/crewing_travel_request_tickets_migration.sql`

## Business Key

- **Composite Key**: (`travel_request_id`, `segment_order`)
- **Source (orchestration)**: Crewing Travel Request Tickets (`travel_ticket_details` → `crewing_travel_request_tickets`)

## Migration Notes

- Migrates travel_ticket_details to crewing_travel_request_tickets. Generates new UUID for id. Maps travel_ticket_id to travel_request_id. Calculates segment_order using ROW_NUMBER. Combines departure_date/departure_time and arrival_date/arrival_time into departure_at and arrival_at.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
