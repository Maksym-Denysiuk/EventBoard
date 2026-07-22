# events.json — Schema

Image is out of scope. Everything else the page currently renders (cards, timeline, filters, modal) can be driven from a single JSON file matching this shape.

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

## Notes on what changes vs. today's hardcoded array

- `date` must be a real ISO string with explicit timezone — today's mock data uses local browser time only, which breaks once events aren't all in one timezone.
- `url` becomes required-if-present real data instead of the synthesized (and non-existent) `eventboard.io/events/{id}`. Missing `url` should hide the visit-link button rather than pointing nowhere.
- `tags` becomes data-driven instead of the hardcoded `tagLabels` object and hardcoded `.tag-*` CSS classes — new tags would still need a CSS color added unless we generate colors programmatically.
- `price` stays a free-form string for now (matches current rendering); if you ever want price-based sorting/filtering, it would need to split into `{amount: number, currency: string}` or a `isFree: boolean` flag.
