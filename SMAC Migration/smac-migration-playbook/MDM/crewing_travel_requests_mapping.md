# Table Mapping: crewing_travel_requests

## Overview

Alias for `crewing_travel_requests`.

- **Canonical mapping**: [crewing_travel_requests_mapping.md](../crewing/crewing_travel_requests_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/crewing_travel_requests_migration.sql`

## Business Key

- **Composite Key**: (`seafarer_id`, `assignment_id`, `departure_date`)
- **Source (orchestration)**: Crewing Travel Requests (`travel_ticket_requests` → `crewing_travel_requests`)

## Migration Notes

- Migrates travel_ticket_requests to crewing_travel_requests. Generates new UUID for id. Maps seafarer_id and assignment_id (relief_id). Converts from_city and to_city to JSONB from_place and to_place.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
