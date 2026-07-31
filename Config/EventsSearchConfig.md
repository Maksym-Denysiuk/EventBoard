# Deployment Config — Event Research Routine

This file supplies the deployment-specific parameters required by `routine-daily-event-research.md`. It does not redefine the data shape (see `Requirements/events-schema.md`) — it only sets search scope and filters.

---

## LOCATION
Porto, Portugal (base point for radius calculation)

## RADIUS_KM
50
— covers Porto city, Vila Nova de Gaia, Matosinhos, Maia, and extends out to Braga, Guimarães, Aveiro, and the near Douro Valley — supporting day-trip / weekend-tour (`trips`) results.

## WINDOW_DAYS
10
— rolling look-ahead from the routine's run date.

## LANGUAGE_PRIORITY
1. English
2. Russian
3. Ukrainian
— prioritize events/communities operating in these languages; note the primary language of each result when known. Do not exclude Portuguese-only events outright, but flag language explicitly so it can be filtered downstream.

## TAG_MAP
Using the tag keys already defined in `Requirements/events-schema-example.md`:

| Tag key | Category | Notes |
|---|---|---|
| `tech` | Professional | AI, technology, software/dev topics |
| `business` | Professional | Business development, startups, pitch/demo days, **new-business openings (cafés, restaurants, bars, co-working/venues, product/platform launches, grand openings)** |
| `art` | Entertainment | Non-hiking creative/experience activities — **master-classes & workshops, tastings (wine/food/coffee), crafting (pottery, candle/soap/jewelry making, painting)**, exhibitions, cooking classes |
| `trips` | Entertainment / Travel | **Trips & outings — guided day trips, excursions, weekend tours/getaways, wine-region & sightseeing tours, group outings to a destination** |
| `sports` | Entertainment | Adrenaline/active activities (karting, escape rooms, strikeball/airsoft, paintball, **racing/motorsport track days**, axe throwing, bouldering) |
| `tournament` | Entertainment | **Competitive/bracketed events — esports & video-game tournaments, board-game/chess/poker nights, pub quizzes & trivia, amateur sports tournaments** |
| `music` | Entertainment | **Live music — concerts, gigs, festivals, DJ sets, open-mic (standalone; no longer requires a couples-social tie-in)** |
| `nightlife` | Social / Entertainment | **Parties, club nights, themed/seasonal parties, launch parties, social celebrations** |
| `community` | Social | Expat groups, language-based communities, recurring social meetups |

Do not introduce new tag keys without updating this map and the schema's `tags` object together. New keys added across recent revisions: `tournament`, `nightlife`, `trips` (and `music` promoted from conditional to standalone; `art` expanded to cover master-classes, tastings, and crafting).

## TAG_MATCH_THRESHOLD
50
— minimum confidence (%) a candidate event must match an existing TAG_MAP entry to reuse that tag. Below this, the routine auto-creates a new tag. Tags are pure mood/browsing labels — they no longer gate inclusion; INTEREST_STORIES/INTEREST_THRESHOLD own that decision entirely.

## TAG_CREATION_GUARDRAILS
When no existing TAG_MAP entry matches at >= TAG_MATCH_THRESHOLD:
- **Naming:** short, lowercase-hyphenated, matching existing style (e.g. `warehouse-rave`, not a sentence).
- **Description:** exactly one sentence — what kind of event this is, not whether it's wanted (interest-rate owns that).
- **Dedup check before creating:** compare against (a) every key in this TAG_MAP table and (b) every key in the live `tags` object in Storage/events.json (may contain tags added in prior runs not yet copied here). Reuse a near-duplicate instead of creating another (e.g. don't create "underground-party" if "warehouse-rave" already means the same thing).
- **No staged approval** — create and use immediately in the same run.
- **Update both places together:** add to this TAG_MAP table AND to the `tags` object written into Storage/events.json (and/or events-shadow.json) in the same run.
- Periodic pruning/merging of near-duplicates is done manually by the user later — no automated merge in scope.

## INTEREST_STORIES
Global, cross-cutting story corpus scoring every candidate's fit — replaces per-tag INCLUDE/EXCLUDE. Judge each candidate holistically against all ten stories, not just the closest one.

**Positive (resonance raises interest_rate):**
1. "I'm looking for business events that build my understanding of how to run a business and sell my own expertise — chatting with people focused on management or pitching solutions, AI workshops, trending-topic sessions, and stock market events (not crypto)."
2. "Full-day wine-region tour — set meeting point, bus included, small mixed group, everything planned, I just show up. Same principle applies broadly: events where I'm not the one making decisions — I'm resting."
3. "Proactive rest where I generate adrenaline and feel alive — karting, strikeball, paintball, rafting, and similar thrill activities."
4. "Evening pottery/craft workshop/music concert/quest, small group, made something with my hands, relaxed pace, no pressure to perform — new physical experience."
5. "Live gig at a small venue — good sound, energy in the room, didn't have to talk to anyone if I didn't want to, just enjoyed the music."

**Negative (resonance lowers interest_rate):**
1. "8-hour coastal hike, no stops, no group interaction, no destination that mattered — bored, tired, time is wasted."
2. "Tried to go to a place (cafe/restaurant/party) that turned out to be an overcrowded event with poor kitchen, Portuguese kitchen only, or too short (30m)."
3. "Sat through a 'networking event' that was just background music at a bar, no structure, no speakers, no reason people were there — left after 20 minutes."
4. "Showed up to a party that turned out to be a private members-only club — wasn't on the list, couldn't get in, wasn't made clear it was closed to the public."
5. "Paid a premium price for something that turned out generic — could've had the same experience for a fraction of the cost, felt ripped off."

Score as interest_rate (integer 0-100) plus a one-line interest_rate_reason naming which story dimension(s) drove it (e.g. "Guided full-day tour, no decisions required — matches positive story 2"). A bare number with no reasoning is not acceptable output.

## INTEREST_THRESHOLD
25
— candidates scoring >= 25 go to Storage/events.json; below 25 go to Storage/events-shadow.json instead. Intentionally permissive as a starting point, tightened over time via manual review of events-shadow.json. Do not change without an explicit config edit here.

---

## Change control
Any change to `LOCATION`, `RADIUS_KM`, `TAG_MAP`, `TAG_MATCH_THRESHOLD`, `TAG_CREATION_GUARDRAILS`, `INTEREST_STORIES`, or `INTEREST_THRESHOLD` should be made here, not in the routine file itself — the routine (`routine-daily-event-research.md`) stays generic and reads these values as inputs.