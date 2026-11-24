# Local Christmas quiz research data

The local dataset lives at `research/quiz-data/`, excluded from Git. It is private
editorial research, outside the schedule app, its resources and its ingestion paths.
Use it for statistical question discovery rather than repeatedly fetching websites.
Continue using varied editorial sources for anecdotes and independent fact-checks.

## Source and coverage

- **Source:** [F1DB release v2026.21.0](https://github.com/f1db/f1db/releases/tag/v2026.21.0),
  published 22 November 2026; downloaded and checked 24 November 2026.
- **Original archive:** `source/f1db-sqlite.zip`; extracted database `source/f1db.db`.
  The original database covers the full upstream history, including pre-2000 records
  and future calendar entries. Use the filtered exports for quiz questions.
- **Archive SHA256:** `26044d26ae25dbfd08cdc5e198f6e78ad2d5ab948185006c0e664de106445bc0`.
  Matched GitHub's release asset digest. The extracted database also matched the
  database inside that verified archive.
- **Quiz result coverage:** 12 March 2000 through 22 November 2026, including
  Las Vegas: 524 Grands Prix, 132 drivers with result entries and 39 circuits.
  The completed-year comparison window, 2000–2025, contains 503 Grands Prix.
- **Attribution:** F1DB contributors, [F1DB](https://github.com/f1db/f1db),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). CSV exports are changed
  versions: filtered, joined and aggregated from the original database. The upstream
  licence and release metadata are retained in `source/LICENSE` and `source/release.json`.

## Local inventory

The `v2026.21.0/` directory holds 17 CSV tables, a matching SQL query beside each
table, and `manifest.json` with row counts, columns, checksums, attribution and build time.
`build.json` preserves the selected inputs, source digest and export queries.
`source/schema.sql` preserves the actual upstream SQLite schema.

| CSV table | Rows | Use |
| --- | ---: | --- |
| `countries` | 249 | Country identities and codes; upstream lookup, not a list of F1 nations |
| `constructors` | 187 | Full upstream constructor lookup, including career totals |
| `drivers_2000_plus` | 132 | Names, birth dates, birthplace and nationality identifiers |
| `circuits_2000_plus` | 39 | Venue geography and current upstream circuit properties |
| `races_2000_plus` | 524 | Race-specific layouts, distance, laps, timing and event identity |
| `gp_results_2000_plus` | 11,024 | Grand Prix classifications, grids, points and driver identities |
| `qualifying_2000_plus` | 10,999 | Qualifying classifications and available timing |
| `sprint_results_2000_plus` | 612 | Sprint results, separate from Grand Prix metrics |
| `pit_stops_2000_plus` | 19,830 | Available pit-stop records; 523 of the 524 Grands Prix |
| `fastest_laps_2000_plus` | 10,530 | Available driver fastest-lap records |
| `season_driver_standings_2000_plus` | 636 | Season standings, including the unfinished 2026 season |
| `driver_stats_2000_plus` | 132 | Grand Prix result entries, wins and podiums in the period |
| `nationality_stats_2000_2025` | 34 | Completed-year national totals and distinct winning drivers |
| `nationality_stats_2000_plus` | 34 | Same measures through the snapshot's latest result |
| `one_win_countries_2000_2025` | 2 | Countries with exactly one Grand Prix victory in that period |
| `one_driver_countries_2000_2025` | 14 | Countries represented by exactly one driver with a result entry |
| `circuit_stats_2000_plus` | 39 | Grand Prix counts, distinct winners and first/last dates in the period |

## Definitions and limits

- `2000_plus` means 2000 through the result cutoff in this snapshot, not live data.
  Future races without results are excluded from the race and circuit exports.
  The original database has two remaining 2026 calendar events without race results.
- Nationality is F1DB's primary `driver.nationality_country_id`. Birth country and second
  nationality are separate fields. This is not a citizenship count or a reconstruction
  of historical race-by-race changes in sporting nationality; verify such edge cases
  before using a nationality question.
- `gp_result_entries` includes non-starters and non-qualifiers recorded in a race result
  table. It is **not starts**. There are 97 entries marked DNS, DNQ, DNPQ, DNP or EX in
  this era. Do not substitute this metric for a starts record.
- Grand Prix wins use final `race_result.position_number = 1`; podiums use positions
  1–3. Distinct winning drivers are counted once per nationality in the selected period.
  Sprints are excluded from those measures.
- Blank CSV fields preserve SQL NULL, not zero. Timing and pit data are not uniformly
  complete. Count the records available for a specific analysis before claiming a record.
- Circuit lookup properties describe the upstream circuit entity. Use race-specific
  fields in `races_2000_plus` for historical distance, layout and turns. Constructor
  lookup totals are career totals; they are not filtered to the quiz era.
- The 2026 standings are provisional at the snapshot cutoff. Standing first does not
  itself establish a championship. Do not infer a champion from rank alone.
- Lap-by-lap leadership and unusual anecdotes are not supplied by these exports.
  Keep the question bank's separately cited evidence for those questions.

## Offline use and refresh

Read the CSVs directly, or query the original SQLite database read-only. For example,
from the repository root, rerun a saved query without any network access:

```sh
sqlite3 -readonly research/quiz-data/source/f1db.db '.read research/quiz-data/v2026.21.0/one_win_countries_2000_2025.sql'
```

The acquisition was a one-time download. Nothing polls, updates itself or performs an
implicit network refresh. Keep this snapshot fixed while writing questions; a new release
should have its own source files, export directory, digest and coverage checks. Do not
overwrite the evidence behind existing questions. The local ad hoc builder is retained
at `tmp/ad-hoc-scripts/build-quiz-tables.py`; its explicit `--config` file selects inputs
and queries, it opens SQLite read-only, and it refuses an existing export directory.

For a question derived from these tables, record the release URL, exact period and metric,
the local SQL filename, and a separate corroborating source where appropriate. The source
database is the numeric research base, not an independent second source for its own CSVs.
The existing Wikipedia mirror remains the broad offline editorial source; access is
documented in the sibling workspace's `docs/KIWIX.md`.
