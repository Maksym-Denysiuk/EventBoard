# Routine: Daily Event Research

**Purpose:** Keep `Storage/events.json` populated with upcoming events for a configured location and set of interest categories, over a rolling window, without re-researching events already captured.

**Schema reference:** `Requirements/events-schema.md` — output must validate against it exactly (`tags` map + `events` array; required fields: `id, name, tag, date, location, price, description`; `url` optional).

---

## Configuration parameters (set per deployment, not hardcoded)

| Parameter | Description |
|---|---|
| `LOCATION` | Base location for the search |
| `RADIUS_KM` | Search radius around `LOCATION` |
| `WINDOW_DAYS` | Rolling look-ahead window (default: 10 days from run date) |
| `TAG_MAP` | The `tags` object from the schema — defines allowed tag keys and their category meaning |
| `INCLUDE_CRITERIA` | Per-tag inclusion rules (e.g. topics/activity types to look for) |
| `EXCLUDE_CRITERIA` | Per-tag exclusion rules (e.g. topics/activity types to skip) |
| `LANGUAGE_PRIORITY` | Optional — preferred language(s) for events/communities, if relevant to the deployment |

This routine must be run with these parameters supplied; it contains no assumptions about a specific person, city, or set of interests.

Config file: `\Config\EventsSearchConfig.md`

---

## Steps

### 1. Load existing state (before any research)
- Read `Storage/events.json`. If it doesn't exist yet, treat the known-events set as empty and skip to Step 2.
- Build a **known-events index** from the existing `events` array using a dedup key of `name + date (day-level) + location` (normalize casing/whitespace).
- Flag (don't yet delete) any existing entries whose `date` is already in the past relative to today — for pruning in Step 5.
- **Do not** re-fetch, re-summarize, or re-analyze anything already in this index during Step 2. This index exists purely to filter, not to inform search queries.

### 2. Research (deep research required, strictly sequential)

This step must use genuine multi-source research, not a single quick lookup. Required tool usage:

- **Execution order — sequential only.** Run one `web_search` or `web_fetch` call at a time and wait for its result before issuing the next. Do not batch or parallelize tool calls, even if the runtime supports concurrent execution. Work through `TAG_MAP` categories one at a time, and within a category, one query at a time. This keeps behavior predictable, keeps token/context usage traceable, and avoids interleaving results across categories.
- **Primary discovery — `web_search` tool, scaled to breadth:** Run a **minimum of 8–15 distinct search queries** per run, spread across `TAG_MAP` categories (not one generic query for everything). Vary query phrasing per category (e.g. category name + "events" + `LOCATION`, + specific activity/topic keywords, + "this week"/date-bounded phrasing). Each query should be short (1–6 words) and meaningfully different from the last — do not repeat the same phrasing expecting different results.
- **Verification — `web_fetch` tool:** For every new candidate event (post-dedup filter, see below), fetch the actual source page rather than relying on the search snippet, to confirm date, price, location, and URL before writing it into the output. Snippets are frequently stale or incomplete. Fetch one candidate at a time, sequentially.
- **Depth check:** If after the initial `web_search` pass a category has yielded few or no results, do not stop — reformulate with different terms (a specific aggregator name, a more specific sub-topic, a different source type) and search again before concluding nothing is available.
- If a dedicated broad/deep research tool is available in the runtime (e.g. an advanced multi-source research task), use it for the initial sweep across all categories at the start of the run, then use `web_search`/`web_fetch` for targeted verification and gap-filling. Do not substitute a single shallow search for this step.
- As each candidate event is found, check it against the known-events index **immediately** (name + date + location match) and discard duplicates before doing any further enrichment (no description-writing, no price lookup, no `web_fetch` for events already stored). This is the token-saving guardrail — filter first, enrich only what's new.

### 3. Sources — explicit list and priority order

Search and verify in this order; higher-priority sources take precedence when information conflicts:

1. **Official event/venue/organizer site** — highest trust; use for date, price, description, and `url`.
2. **Meetup / Eventbrite** — treat listed RSVP/attendee counts as an activity/legitimacy signal.
3. **Google Maps listing + reviews** — use to confirm a venue exists, is open, and matches `LOCATION`/`RADIUS_KM`; reviews can surface recency.
4. **Event aggregators** (e.g. 10times, dev.events, or category-relevant local aggregators) — useful for discovery, but verify against a higher-priority source before including.
5. **Facebook / community / expat groups** — lowest trust; only use if recency can be verified (recent posts/comments), and prefer to corroborate with a higher-priority source when possible.

If a source is behind a login wall or activity/recency cannot be confirmed, note that explicitly rather than treating it as verified.

### 4. Format
For each new event, construct a JSON object matching the schema exactly:
- `id`: `evt_YYYY_MMDD_slug` (slug = lowercase, hyphenated short name; ensure uniqueness against both existing and newly-added ids)
- `tag(s)`: 1 to **3 tags maximum** per event, each a key from `TAG_MAP` — do not invent new tags without adding them to the map. Sort the assigned tags by relevance to the event, most relevant first, and only ever populate the `tag` field with the top (first) one — the UI renders only that single value, so it must be the best-fit category, not just whichever was found first.
- `date`: ISO 8601 with explicit timezone offset
- `location`, `price`, `description`, `url` (optional) per schema — `price` stays a free-form display string per current schema

An event only counts as "constructed" once every required field above is filled in and valid — see the atomic-write guardrail in Step 6 for how partially-built events are handled.

> Note: `Requirements/events-schema.md` currently defines `tag` as a single required string. This routine treats tag assignment as "pick up to 3 candidates, sort by relevance, keep the top one" so the stored `tag` value is always the best-fit choice — it does not write multiple tags into the JSON unless the schema is updated to support an array. If multi-tag storage is wanted, update the schema first so `tag` → `tags: [string, string?, string?]`, sorted primary-first.

### 5. Deduplicate (before writing)
- Merge: existing events (minus any pruned in Step 1) + newly formatted events.
- Run a final dedup pass over the **merged** list using the same key (`name + date + location`) — on collision, keep the entry with more complete data (has `url`, more specific `description`), discard the other.
- Verify every `tag` used still exists in `TAG_MAP`.

### 6. Store (atomic write only)
- Write the deduplicated, merged object back to `Storage/events.json`, preserving the `tags` map (add new tag keys only if `TAG_MAP` was updated).
- **Atomic-write guardrail:** Only include an event object in the write if it is fully constructed per Step 4 (all required fields present and valid). Never write a partial/in-progress event — no event with missing, placeholder, or truncated fields is written, even temporarily.
- **Token-exhaustion handling:** If a turn is at risk of ending (context/token budget running out) before an event is fully constructed, discard that in-progress candidate rather than writing it half-finished. It stays undiscovered and will be picked up on a future run — do not persist partial data with the intent of completing it later.
- Build the full merged JSON object in memory, validate it against the schema, and write it in a single write operation — never stream partial JSON to the file. This guarantees `Storage/events.json` is valid JSON at the end of every run, even if the run is interrupted beforehand.
- Default behavior: **prune** events flagged as past-dated in Step 1, keeping the file limited to upcoming events (forward-looking timeline use case). Change to retain a historical log only if explicitly configured to do so.

---

## Guardrails (hard rules)
1. **No re-analysis of known events.** Load and index `Storage/events.json` *before* searching. Use that index only to filter/skip — never spend search or writing effort re-describing an event already stored.
2. **Deep research is mandatory, not optional.** Minimum 8–15 varied `web_search` queries per run across categories, plus `web_fetch` verification of each new candidate's source page. A single search pass is not sufficient.
3. **Strictly sequential execution.** No parallel or batched tool calls at any point in the routine — one search/fetch at a time, one category at a time.
4. **Follow the source priority order in Step 3** when information conflicts between sources.
5. **Deduplicate before every write.** No write to `events.json` happens without a final merge+dedup pass keyed on `name + date + location`.
6. **Atomic writes only.** Never write a partial/incomplete event object. If a run ends before an event is fully constructed, that candidate is discarded, not persisted half-done — `events.json` must be valid, complete JSON after every write.
7. **Never fabricate** `url`, `price`, or `date`. If unverifiable, omit `url` (per schema) and either exclude the event or clearly flag it as unconfirmed in working notes (not in the JSON) — never guess.
8. **`INCLUDE_CRITERIA`/`EXCLUDE_CRITERIA`/`RADIUS_KM` always apply** as configured — this routine does not relax them.
9. **Max 3 tag candidates per event, sorted by relevance, top one wins.** Since the UI only shows the first tag, never assign a tag arbitrarily or by search-result order — the stored `tag` must be the single most relevant category for that event.

---

## Completion

When everything above is done, push changes to the `Master` branch.

Then set the completion condition so the run continues until the search space is exhausted:

```
/goal no new events found
```
