# EventBoard — Page Analysis

This is a single-file static site (`index.html`) — a mock event board with 15 hardcoded events, all client-side (no backend, no API).

## Current state

- **Data source**: `events` array is hardcoded JS (`index.html:795-811`), 15 fake events across 6 tags (tech, music, business, art, sports, community), dates generated relative to today via `d(offsetDays, hour)`.
- **Modules**: filters/search/sort, a day/week/year timeline, a card grid, and a detail modal — all driven by that one in-memory array.

### Placeholders that are fake/broken today

- Every event card banner is just a CSS gradient — no real images (`.event-card-banner`, `.modal-banner`)
- `modalVisitLink` points to `https://eventboard.io/events/{id}` — a domain that doesn't exist
- Footer contacts (`hello@eventboard.io`, phone number, address) are placeholder
- Login button just shows an `alert()` — no real auth
- "Visit event page", pricing links, social/product links in the footer all go to `#`

## What's needed to make this a real, functioning product

1. **Real event data** — either:
   - A backend/API endpoint returning events (id, name, tag, start datetime, location, price, description, image URL, external ticket link), or
   - A CMS/spreadsheet feed, or
   - If this stays a static demo, just better/more realistic sample data you provide.

2. **Event images** — real banner/thumbnail image URLs per event (currently gradient placeholders).

3. **Real destination URLs** — actual ticket/event pages to link `modalVisitLink` to, or a decision to keep it as a "would link out" demo.

4. **Real business info** — actual contact email/phone/address for the footer, or confirmation that placeholders are fine for a demo/portfolio piece.

5. **Auth requirements** — if login should actually work: what provider (email/password, OAuth), and what it should unlock (e.g., save/RSVP events, organizer dashboard).

6. **Location data granularity** — currently just a text string; if you want maps/distance/filtering by location, you'd need structured geo data (lat/lng or city/region fields).

7. **Timezone handling** — dates are built from the browser's local `today`; if events are real and multi-timezone, you'd need to store UTC + a timezone per event.

## Input file schema (`events.json`)

Image is out of scope for now, so banners stay as the existing CSS gradient. Everything else the page currently renders (cards, timeline, filters, modal) can be driven from a single JSON file matching this shape:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tags", "events"],
  "properties": {
    "tags": {
      "type": "object",
      "description": "Maps a tag id to its display label. Only tags listed here get a themed color pill (tag-tech, tag-music, etc. in CSS); unknown tags fall back to an untyled pill.",
      "additionalProperties": { "type": "string" }
    },
    "events": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "name", "tag", "date", "location", "price", "description"],
        "properties": {
          "id":          { "type": ["string", "number"], "description": "Unique identifier." },
          "name":        { "type": "string" },
          "tag":         { "type": "string", "description": "Must match a key in the top-level tags map." },
          "date":        { "type": "string", "format": "date-time", "description": "ISO 8601 with timezone offset, e.g. 2026-08-14T18:00:00-04:00." },
          "location":    { "type": "string" },
          "price":       { "type": "string", "description": "Free-form display string, e.g. \"Free\" or \"$18\"." },
          "description": { "type": "string" },
          "url":         { "type": "string", "format": "uri", "description": "Real ticket/event page. If omitted, the modal's \"Visit event page\" button should be hidden." }
        }
      }
    }
  }
}
```

Example:

```json
{
  "tags": {
    "tech": "Tech",
    "music": "Music",
    "business": "Business",
    "art": "Art",
    "sports": "Sports",
    "community": "Community"
  },
  "events": [
    {
      "id": "evt_2026_0814_react",
      "name": "React Summit Meetup",
      "tag": "tech",
      "date": "2026-08-14T09:00:00-04:00",
      "location": "Downtown Tech Hub, 55 Market St",
      "price": "Free",
      "description": "A community meetup covering the latest in React, hooks, and server components.",
      "url": "https://meetup.com/react-summit-2026"
    }
  ]
}
```

**Notes on what changes vs. today's hardcoded array:**
- `date` must be a real ISO string with explicit timezone — today's mock data uses local browser time only, which breaks once events aren't all in one timezone.
- `url` becomes required-if-present real data instead of the synthesized (and non-existent) `eventboard.io/events/{id}`. Missing `url` should hide the visit-link button rather than pointing nowhere.
- `tags` becomes data-driven instead of the hardcoded `tagLabels` object and hardcoded `.tag-*` CSS classes — new tags would still need a CSS color added unless we generate colors programmatically.
- `price` stays a free-form string for now (matches current rendering); if you ever want price-based sorting/filtering, it would need to split into `{amount: number, currency: string}` or a `isFree: boolean` flag.

## Open question

Given it's currently a self-contained demo, this could go two ways:

- **(a)** Treat it as a portfolio/demo piece and just polish it further, or
- **(b)** Wire it to real data.

Which one?
