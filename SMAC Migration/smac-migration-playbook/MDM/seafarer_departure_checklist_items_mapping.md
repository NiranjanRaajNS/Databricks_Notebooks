# Table Mapping: seafarer_departure_checklist_items

## Overview

Alias for `seafarer_departure_checklist_items`.

- **Canonical mapping**: [seafarer_departure_checklist_items_mapping.md](../crewing/seafarer_departure_checklist_items_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/seafarer_departure_checklist_items_migration.sql`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departure Checklist Items (`seafarer_departures,seafarer_checklists` → `seafarer_departure_checklist_items`)

## Migration Notes

- Migrates seafarer_departure_checklist_items from seafarer_departures and seafarer_checklists. Joins on seafarer_departures.id = seafarer_checklists.seafarer_departure_id. Maps departure_checklist_id to checklist_item_id via departure_checklist master table. Converts deviation_reviewers JSONB to UUID array. Sets deviation_flag based on deviation_note presence.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
