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

## INCLUDE_CRITERIA (per tag)

**`tech` / `business` — Professional**
- In-person only, any cadence (one-off or recurring)
- Topics: AI, technology, business development, startup demo days / pitch events, product/program management networking
- New-business openings: grand openings and launch events for cafés, restaurants, bars, co-working spaces, venues, and product/platform launches — include when open to the public (opening night, tasting/preview, ribbon-cutting)
- Prefer events with visible RSVP/attendee signals (Meetup/Eventbrite)

**`sports` / `art` — Entertainment**
- Novelty, adrenaline, or clear-goal activities: karting, racing/motorsport track days, escape rooms, wine tasting, strikeball/airsoft, paintball, VR/experience venues, axe throwing, bouldering, cooking classes
- Master-classes & workshops, tastings (wine/food/coffee/cheese), and crafting sessions (pottery, candle/soap/jewelry making, painting/sip-and-paint) all qualify under `art`
- Open to hidden-gem or last-minute options if they fit the criteria
- Moderate/standard leisure pricing — no need to filter for budget/luxury tiers
- No dietary/health restriction filtering needed (comfortable with light alcohol, no allergies)

**`trips` — Entertainment / Travel**
- Guided or organized day trips, excursions, and weekend tours/getaways with a set date and meeting point (wine-region tours, sightseeing, coastal/nature outings with a clear itinerary)
- Include destinations within the wider `RADIUS_KM` reach (Braga, Guimarães, Aveiro, Douro Valley) and organized outings that depart from Porto
- Prefer bookable/RSVP-able group trips; couples-friendly and mixed-group both qualify
- Note duration (half-day / full-day / overnight) and whether transport is included

**`tournament` — Entertainment**
- Competitive/bracketed formats: esports & video-game tournaments, board-game/chess/poker nights, pub quizzes & trivia leagues, amateur sports tournaments (5-a-side, padel, etc.)
- Both spectator and participant events qualify; prefer ones open to newcomers or casual sign-ups
- Note skill tier / entry requirements when visible

**`music` — Entertainment**
- Standalone live music now qualifies: concerts, gigs, festivals, DJ sets, open-mic and jam nights
- Prefer ticketed or listed events with a clear date/venue; smaller intimate venues are welcome
- Note genre and whether it's seated vs. standing/club-style when known

**`nightlife` — Social / Entertainment**
- Parties, club nights, themed/seasonal parties, launch/opening parties, social celebrations
- Couples-friendly and mixed-group settings both qualify; flag age/dress-code or members-only gating when visible

**`community` — Social**
- Recurring or one-off meetups: expat communities, English/Russian/Ukrainian-speaking social groups, couples-friendly clubs, hobby groups
- Explicitly distinguish activities *for* couples (e.g. couples cooking class) vs. mixed groups simply *welcoming* to couples

## EXCLUDE_CRITERIA (per tag)

**`tech` / `business`**
- UI/UX-specific design events or news
- Non-business / non-tech topics

**`sports` / `art`**
- Hiking
- Routine/purposeless walks
- Purposeless cycling (leisure/scenic cycling with no clear goal)

**`trips`**
- Pure hiking/trekking trips or purposeless scenic walks (consistent with the `sports`/`art` exclusions)
- Self-guided routes with no organized event, date, or booking
- Multi-day trips extending beyond the `WINDOW_DAYS` look-ahead

**`tournament`**
- Online-only / remote tournaments (in-person only, consistent with the rest of the config)
- Youth/under-18 or licensed-professional-only competitions

**`music`**
- Purely religious/liturgical services
- Background/ambient music at unrelated venues (not a billed music event)

**`nightlife`**
- 18+ venues the couple can't both attend, or strict members-only clubs with no public entry
- Corporate/private invite-only parties not open to the public

---

## Change control
Any change to `LOCATION`, `RADIUS_KM`, or `TAG_MAP` should be made here, not in the routine file itself — the routine (`routine-daily-event-research.md`) stays generic and reads these values as inputs.