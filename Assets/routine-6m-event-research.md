# Routine: 6m Event Research

**Purpose:** Keep `Storage/events.json` populated with upcoming events for a configured location and set of interest categories, over a rolling window, without re-researching events already captured.

**Schema reference:** `Requirements/events-schema.md` — output must validate against it exactly (`tags` map + `events` array; required fields: `id, name, tag, date, location, price, description`; `url` optional). `interest_rate`/`interest_rate_reason` are schema-optional (for backward compatibility with pre-existing events) but must be populated by this routine for every event it writes, going forward.

---

## Configuration parameters (set per deployment, not hardcoded)
We are doing 6m analysis so that parameter: `WINDOW_DAYS` should always be 6 month range

| Parameter | Description |
|---|---|
| `LOCATION` | Base location for the search |
| `RADIUS_KM` | Search radius around `LOCATION` |
| `TAG_MAP` | The `tags` object from the schema — defines allowed tag keys and their category meaning (pure mood/browsing labels, not a taste gate) |
| `INTEREST_STORIES` | Global story corpus (positive + negative) scoring every candidate's genuine narrative fit — the sole taste gate |
| `INTEREST_THRESHOLD` | Minimum `interest_rate` to land in `Storage/events.json`; below it, the candidate goes to `Storage/events-shadow.json` |
| `TAG_MATCH_THRESHOLD` | Minimum confidence (%) to reuse an existing `TAG_MAP` tag before auto-creating a new one |
| `LANGUAGE_PRIORITY` | Optional — preferred language(s) for events/communities, if relevant to the deployment |

This routine must be run with these parameters supplied; it contains no assumptions about a specific person, city, or set of interests.

Config file: `\Config\EventsSearchConfig.md`

---

## Steps

### 1. Load existing state (before any research)
- Read `Storage/events.json`. If it doesn't exist yet, treat the known-events set as empty and skip to Step 2.
- Build a **known-events index** from the existing `events` array using a dedup key of `name + date (day-level) + location` (normalize casing/whitespace).
- Flag (don't yet delete) any existing entries whose `date` is already in the past relative to today — for pruning in Step 5.
- **Past-date check:** an entry counts as past-dated if its `date` (parsed with its timezone offset) is earlier than the current run's date/time. Compare against actual "now", not a cached or approximate value.
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
- `tag`: assigned in Step 4b (match-or-create), not here.
- `date`: ISO 8601 with explicit timezone offset
- `location`, `price`, `description`, `url` (optional) per schema — `price` stays a free-form display string per current schema

An event only counts as "constructed" once every required field above (plus `interest_rate`/`interest_rate_reason`/`tag` from Steps 4a/4b) is filled in and valid — see the atomic-write guardrail in Step 6 for how partially-built events are handled.

> Note: `Requirements/events-schema.md` currently defines `tag` as a single required string. This routine treats tag assignment as "pick up to 3 candidates, sort by relevance, keep the top one" so the stored `tag` value is always the best-fit choice — it does not write multiple tags into the JSON unless the schema is updated to support an array. If multi-tag storage is wanted, update the schema first so `tag` → `tags: [string, string?, string?]`, sorted primary-first.

### 4a. Score interest_rate
- Judge each fully-formatted candidate against the full `INTEREST_STORIES` corpus (all 10 stories, positive and negative, holistically) — not just the closest one.
- Produce `interest_rate` (0-100 integer) and `interest_rate_reason` (one line, naming the driving story dimension(s), e.g. "Guided full-day tour, no decisions required — matches positive story 2"). Never blank, never a placeholder.
- This is independent of tag assignment (Step 4b) — `interest_rate`/`INTEREST_THRESHOLD` is the sole taste gate now.
- A below-threshold score is a legitimate, expected outcome, not a failure to avoid — it routes the candidate to `Storage/events-shadow.json` in Step 7, it does not discard it.

### 4b. Match or create tag
- Score confidence (0-100%) of the candidate against every `TAG_MAP` entry's description (up to 3 candidates considered, sorted by relevance).
- If the top candidate's confidence is >= `TAG_MATCH_THRESHOLD`, use that tag and populate the `tag` field with it (single best-fit value — the UI renders only that one).
- If no `TAG_MAP` entry reaches `TAG_MATCH_THRESHOLD`, auto-create a new tag immediately per `TAG_CREATION_GUARDRAILS`: check for near-duplicates against both `TAG_MAP` and the live `tags` object in `Storage/events.json` first, then add the new key to `TAG_MAP` in the config and to the `tags` object written in Step 7, same run.
- Tag assignment never filters inclusion — it only labels an event already scored in Step 4a.

### 5. Prune past-dated events (delete)
- Before merging or writing anything, remove every entry flagged in Step 1 as past-dated from the working copy of the existing events set — this is a hard delete from the dataset that will be written, not a soft flag.
- Apply this **independently to both `Storage/events.json` and `Storage/events-shadow.json`** — same rule, two datasets, run separately against each file's own existing entries.
- This applies regardless of whether the run finds any new events — even a run that discovers nothing must still drop expired entries from both files.
- Default behavior: keep both files limited to upcoming events only (forward-looking timeline use case). Only retain past events if explicitly configured elsewhere to keep a historical log.
- Note in the run's working notes how many events were pruned from each file and their names/dates, so it's traceable in the completion summary (report counts for `events.json` and `events-shadow.json` separately).

### 6. Deduplicate (before writing)
- For each file independently: merge existing events (already pruned of past-dated entries in Step 5) + newly formatted candidates routed to that file in Step 7's split (below threshold → shadow, at/above → main).
- Run a final dedup pass over each **merged** list using the same key (`name + date + location`) — on collision, keep the entry with more complete data (has `url`, more specific `description`), discard the other.
- An event is never present in both files — routing by `interest_rate` in Step 7 is exclusive.
- Verify every `tag` used still exists in `TAG_MAP`.

### 7. Store (atomic write only)
- **Two atomic writes, not one.** Route each fully-formatted candidate by its `interest_rate` from Step 4a: `>= INTEREST_THRESHOLD` → `Storage/events.json`; below it → `Storage/events-shadow.json`. Write the deduplicated, merged object back to each file, preserving each file's own `tags` map (add new tag keys to both files' `tags` objects when `TAG_MAP` was updated in Step 4b).
- **Atomic-write guardrail:** Only include an event object in a write if it is fully constructed per Steps 4/4a/4b (all required fields present and valid, `interest_rate`/`interest_rate_reason`/`tag` populated). Never write a partial/in-progress event — no event with missing, placeholder, or truncated fields is written, even temporarily.
- **Token-exhaustion handling:** If a turn is at risk of ending (context/token budget running out) before an event is fully constructed, discard that in-progress candidate rather than writing it half-finished. It stays undiscovered and will be picked up on a future run — do not persist partial data with the intent of completing it later.
- Build each file's full merged JSON object in memory, validate it against the schema, and write it in a single write operation — never stream partial JSON to either file. This guarantees both files are valid JSON at the end of every run, even if the run is interrupted beforehand.
- Skip writing a file only if nothing changed in it (no new candidates routed to it and nothing pruned from it this run).

---

## Guardrails (hard rules)
1. **No re-analysis of known events.** Load and index `Storage/events.json` *before* searching. Use that index only to filter/skip — never spend search or writing effort re-describing an event already stored.
2. **Deep research is mandatory, not optional.** Minimum 8–15 varied `web_search` queries per run across categories, plus `web_fetch` verification of each new candidate's source page. A single search pass is not sufficient.
3. **Strictly sequential execution.** No parallel or batched tool calls at any point in the routine — one search/fetch at a time, one category at a time.
4. **Follow the source priority order in Step 3** when information conflicts between sources.
5. **Deduplicate before every write.** No write to `events.json` or `events-shadow.json` happens without a final merge+dedup pass keyed on `name + date + location`, run independently per file.
5a. **Prune past-dated events every run.** Step 5 hard-deletes any stored event whose date is already behind the current run date, in both files independently, before dedup/write — this happens even on a run that finds zero new events.
6. **Atomic writes only.** Never write a partial/incomplete event object. If a run ends before an event is fully constructed, that candidate is discarded, not persisted half-done — both `events.json` and `events-shadow.json` must be valid, complete JSON after every write.
7. **Never fabricate** `url`, `price`, `date`, or `interest_rate_reason`. If unverifiable, omit `url` (per schema) and either exclude the event or clearly flag it as unconfirmed in working notes (not in the JSON) — never guess. `interest_rate_reason` must reflect genuine reasoning against `INTEREST_STORIES`, never reverse-engineered to justify a pre-picked score.
8. **`INTEREST_STORIES`/`INTEREST_THRESHOLD`/`RADIUS_KM` always apply.** The story corpus is the sole taste gate — tag assignment never filters inclusion, it only labels an already-scored event.
9. **Max 3 tag candidates per event, sorted by relevance, top one wins.** Since the UI only shows the first tag, never assign a tag arbitrarily or by search-result order — the stored `tag` must be the single most relevant category for that event, decided via the match-or-create process in Step 4b (`TAG_MATCH_THRESHOLD` against `TAG_MAP`, else auto-create per `TAG_CREATION_GUARDRAILS`).
10. **Route strictly by `interest_rate` vs. `INTEREST_THRESHOLD`.** Every scored candidate goes to exactly one file — never both, never skipped. A sub-threshold candidate must still be written to `Storage/events-shadow.json`; its value depends on capturing everything scored, not just what was liked.
11. **New tags are created immediately, never staged for approval.** No pending/approval step for `TAG_CREATION_GUARDRAILS` — create and use in the same run.

---

## Completion

Before committing: skim `Storage/events-shadow.json` for entries added or already present — read `interest_rate`/`interest_rate_reason` for anything that seems miscalibrated (too low for something appealing, too high for something mediocre). Lightweight read each run, not a mandatory audit — purpose is surfacing signal for tightening `INTEREST_STORIES`/`INTEREST_THRESHOLD` over time. Note anything notable in the commit message; no action required unless something looks clearly wrong.

When everything above is done, git add -> commit -> push changes to the remote `Master` branch.

Then set the completion condition so the run continues until the search space is exhausted:

```
/goal no new events found
```
