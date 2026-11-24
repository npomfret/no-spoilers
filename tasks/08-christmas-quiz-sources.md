# Task 08: Christmas Quiz — Facts, Trivia and Data Sources

**Status:** Source catalogue and local statistical datasets built; question authoring continues.
**Sources checked:** Catalogue 2026-11-23; pinned dataset and nationality analysis 2026-11-24.
**Target:** Christmas 2026, assumed from the request; delivery date and host surface are unconfirmed.
**Question era:** 2000 onward, inclusive (confirmed by the user).
**Editorial direction:** Fun, creative questions about oddities, outliers, little-known
trivia and surprising statistics (confirmed by the user).
**Question format:** Four-option multiple choice, following the first approved question.
**Optional clues:** Selected questions may offer a clue. Correct answers earn 1 point
unaided or ½ point with a clue; offer it before submission and disclose its cost first.
**Current-season coverage:** Include 2026 questions, especially Las Vegas. Evidence for
the current drafts stops after Las Vegas (checked 2026-11-23).
**Question provenance:** Record direct source links and a checked date for each question
(explicitly requested by the user).
**Question bank:** [Christmas quiz questions](../docs/christmas-quiz-questions.md).

## Purpose and scope

Find a varied set of reliable sources for an embedded motorsport quiz covering drivers,
results, circuits, teams, cars, rules and unusual history. The user specifically wants a
variety of sources, so a statistics database alone is insufficient. This task records
source discovery, suitability and local editorial datasets; it does not implement a quiz
or import data into the app.

## Recommendation

Use **our Wikipedia mirror as a broad trivia research source** and **F1DB as the leading
candidate for structured historical data**, supplemented by **circuit operators, team
heritage archives, FIA regulations, official biographies and independent historical
references** for variety and verification. Wikidata can help with
identities and multilingual labels. Jolpica and OpenF1 are useful research alternatives,
but their published restrictions need resolving before product reuse.

Prefer a deliberately authored, fact-checked Christmas question pack over embedding a
third-party quiz or generating questions from a live feed. This is a proposed approach,
not an agreed architecture. Public access does not establish permission to redistribute
data, copy prose, reuse media or embed a quiz.

## Source catalogue

The inventory below is the researched shortlist, not an exhaustive list of websites.
“Reference” means useful for research and verification; it does not mean licensed for
copying into the app. Coverage descriptions come from the linked pages, not a completeness
audit of their underlying datasets.

### Our Wikipedia copy — broad trivia and cited references

**Canonical access documentation:**
[`snowmonkey-proxy-common/docs/KIWIX.md`](../../snowmonkey-proxy-common/docs/KIWIX.md)
in the sibling workspace, supplied by the user and read during this research.

The documentation describes an English Wikipedia mirror with all articles and no images,
served by Kiwix on the tools host. Access is through the documented SSH tunnel using an
approved key, then `http://127.0.0.1:8180`; article paths are
`/content/current/A/<Article_Name>`. Reuse that access mechanism; no new mirror, public
route or content service is needed for research.

- **Value:** a broad entry point for driver biographies, constructors, circuits, cars,
  terminology, historical seasons and unusual stories. Follow article references to
  primary evidence; use the other source families below for corroboration.
- **Freshness:** the checked document names `wikipedia_en_all_nopic_2026-06.zim` as the
  installed archive. Its November installation date is not the content date. A monthly
  refresh job checks for releases, described as roughly quarterly. Verify the actual
  archive in use before authoring; June content cannot establish later-2026 facts.
- **Reuse:** Wikipedia article text is generally CC BY-SA 4.0, with attribution and
  share-alike requirements for adapted text. See the [Wikimedia reuse terms](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use#7._Licensing_of_Content)
  and the particular article's notices. Owning a mirror does not remove those obligations.
  Distinguish checking facts and writing original questions from adapting article prose.
- **Limits:** Wikipedia is a secondary, collaboratively edited reference, not final
  authority for disputed stories or records. Retain article title, canonical URL,
  available revision information, archive filename and cited references. The no-image
  archive supplies no picture-round assets or media permissions.

Mirror availability and the currently served archive were **not checked live** in this
source-discovery pass; the infrastructure details above are documentation-derived.

### Structured data and research tools

| Source | Coverage and quiz value | Access and reuse evidence | Assessment |
| --- | --- | --- | --- |
| **[F1DB](https://github.com/f1db/f1db)** | Seasons from 1950 onward; drivers, constructors, engines, tyres, circuits/layouts, race and qualifying results, standings and other statistics. Broad base for historical questions. | Versioned [downloads](https://github.com/f1db/f1db/releases) in JSON, CSV, SQL and SQLite. Repository [licence](https://github.com/f1db/f1db/blob/main/LICENSE): CC BY 4.0. | **First candidate for structured data.** Pin a release and verify the chosen fields and era. |
| **[Jolpica-F1](https://github.com/jolpica/jolpica-f1)** | Ergast successor with driver, constructor, circuit, season, results, qualifying, sprint, lap and pit-stop queries. | [API documentation](https://github.com/jolpica/jolpica-f1/blob/main/docs/README.md). [Data terms](https://github.com/jolpica/jolpica-f1/blob/main/TERMS.md): CC BY-NC-SA 4.0; commercial users must contact the operator. Apache-2.0 code licensing does not replace those terms. | Useful for targeted research and comparisons. **Do not assume commercial app reuse is permitted.** Use the successor rather than the retired Ergast service. |
| **[OpenF1](https://openf1.org/)** | Detailed modern timing, laps, stints, pits, weather, telemetry and session data. [Documentation](https://openf1.org/docs/) advertises history from 2023 onward. | Historical JSON/CSV access is free without authentication; live access requires a subscription. Homepage describes personal-use tiers and non-commercial intended use. | Specialist modern-data reference; unnecessary for a first general-history pack. Product reuse requires clarification. |
| **[FastF1](https://github.com/theOehrly/Fast-F1)** | Python tooling for timing, telemetry, session results and Jolpica queries; helpful for investigating harder numerical questions. | MIT-licensed software, Pandas-based analysis and request caching. This does **not** establish redistribution rights over upstream data. | Optional authoring/research tool, not a separate independent corroborating source when it reads Jolpica. Documentation site returned HTTP 403 during research; repository README was inspected instead. |
| **[Wikidata](https://www.wikidata.org/wiki/Wikidata:Data_access)** | Linked entities and labels for drivers, teams, countries and circuits; potential biography/geography enrichment. | [Structured data is CC0](https://www.wikidata.org/wiki/Wikidata:Licensing); query/API/download access. Other wiki text and linked images have separate terms. | Useful supplement. Check individual statements, references, qualifiers and dates; missing data must not become invented answers. |

F1DB's [schema documentation](https://github.com/f1db/f1db#f1db-json-schema) is the starting
point for a later field audit. Its README advertises post-race releases, but this research
does not establish uniform field availability across eras. [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
allows commercial adaptation with attribution, a licence link and change notices; it does
not grant every other right that a product may need. Preserve source/version provenance
and assess the intended distribution before bundling anything.

Jolpica's checked documentation requires an identifying User-Agent, paginates at a maximum
of 100 records, and currently [limits unauthenticated requests](https://github.com/jolpica/jolpica-f1/blob/main/docs/rate_limits.md)
to 4/second and 500/hour. These are research notes, not permission or a product integration
contract. Recheck terms and limits if selected.

### Official records, biographies and rules

| Source | Coverage and quiz value | Access/reuse limits and role |
| --- | --- | --- |
| **[Official results archive](https://www.formula1.com/en/results)** | Official season/race reference for checking historical classifications and answers derived from results. | Browsable pages, not an open-data licence. Research reference; bulk extraction and redistribution are not assumed permitted. |
| **[Official driver Hall of Fame](https://www.formula1.com/en/drivers/hall-of-fame)** | Biographies and career stories; useful leads for personality, career and historical rounds. Complements numerical datasets. | Editorial reference. Verify the exact biography and write original questions; do not copy articles or photographs. Champion-focused, so not representative of every driver. |
| **[FIA regulations and archives](https://www.fia.com/regulation/category/110)** | Sporting and technical rules for flags, procedures, car requirements and how rules changed. | Public documents with dated issues and archived editions. Cite the applicable season, issue and article when validating a question. No blanket republication permission established. |

The official series' [rights guidelines](https://www.formula1.com/en/information/guidelines.4EOKE9RRqevL4niTK9kWyt)
restrict reuse of written content, statistics/timing databases, apps, competitions and
branding. An accessible website or an existing official quiz is not an embeddable content
licence. No permission to embed a ready-made official quiz was established here.

### Circuit history and geography

| Source | Coverage and quiz value | Access/reuse limits and role |
| --- | --- | --- |
| **[Silverstone — Our History](https://www.silverstone.co.uk/about/our-history)** | Circuit operator's timeline, venue origins and development. A primary source for local-history questions. | Public editorial pages. Verify dates and scope against another reference; no open reuse licence established for prose or images. |
| **[Monza — History](https://www.monzanet.it/en/history/)** | Circuit operator's historical account, construction, banking and layout changes. Adds a second venue and a different national perspective. | Public editorial page. Distinguish the venue's wider motorsport history from championship events; check translation and chronology before drafting. No open reuse licence established. |
| **[RacingCircuits.info](https://www.racingcircuits.info/)** | Independent circuit encyclopedia organised by geography, including historic and defunct venues. Leads for layout, location and venue-history questions. | Browsable reference. Check individual circuit pages against operators; no open data/API or media reuse licence established in this pass. Do not copy track maps. |

### Team heritage and independent historical references

| Source | Coverage and quiz value | Access/reuse limits and role |
| --- | --- | --- |
| **[McLaren Racing Heritage](https://www.mclaren.com/racing/heritage/)** | Team's own archive of its founder, people, cars and racing history. Adds engineering and team-origin topics beyond results. | Primary source for its own history, with an interested editorial perspective. Separate Formula 1 from its other series and corroborate comparative claims. No open prose/media licence established. |
| **[Motor Sport Database](https://www.motorsportmagazine.com/database/)** | Independent searchable driver, team, circuit, race and championship encyclopedia, with links to historical editorial material. | Good second reference for biographies and historical context. No public bulk-data licence established; inspect individual article access and terms before reuse. |
| **[STATS F1](https://www.statsf1.com/en/default.aspx)** | Specialist independent statistics covering seasons, drivers, constructors, engines, tyres, nations and circuits, plus historical material. | Useful cross-check and question lead. The site explicitly prohibits reuse of authors' text in other media without authorisation. No blanket data redistribution permission established. |

These are fifteen catalogue entries, with different roles. Agreement between websites
does not prove independence: check cited origins, especially for numerical records.

## Intended variety

These are question categories to explore, not approved product content or drafted questions.

| Topic | Starting sources | Check before authoring |
| --- | --- | --- |
| Driver identities, backgrounds and careers | Wikipedia mirror, biographies, Wikidata, Motor Sport | Sporting nationality versus birthplace; name changes; effective dates. |
| Historical results and records | F1DB, official archive, STATS F1 | Final classification, penalties, ties, sprint inclusion and a fixed cutoff. |
| Circuit geography and origins | Circuit operators, RacingCircuits.info, Wikidata | Venue versus layout, opening date versus first championship event. |
| Teams, founders, cars and engineering | Team heritage, F1DB, Motor Sport | Constructor identity versus entrant/sponsor name; chassis versus engine. |
| Rules and technical knowledge | FIA regulations | Exact season and document issue; avoid presenting a changed rule as timeless. |
| Unusual history and anecdotes | Wikipedia mirror and its citations, team/circuit archives, biographies, Motor Sport | Trace to an attributable source; corroborate stories and superlatives. |

Use several source families and a mix of seasons from 2000 onward, with easy and difficult
questions. The cutoff applies to the subject matter, not the source's publication date;
broader historical archives remain useful after filtering. Compute statistical questions
within an explicitly stated period starting no earlier than 2000. Prioritise unusual
incidents, unexpected connections and surprising numbers, with an entertaining explanation
after each answer. Avoid a pack dominated by winners or one team's history. For each future
question retain its exact source page, access date, relevant edition/version, rationale,
rights status and verification evidence. Resolve ambiguous answers before publication.

## No Spoilers scope decision

The current [spoiler-safety rules](../.claude/rules/spoiler-safety.md) permit only schedule
identity, location, kind and timing in product data. Results, records and driver-performance
data are prohibited. Driver biographies and other non-schedule trivia also exceed the
current permitted product scope. An age cutoff, opt-in button or hidden screen would not
by itself satisfy that architectural guarantee.

This file is private planning research. It contains source descriptions, not results,
quiz answers or downloaded datasets. No product input, model, cache, fixture, UI, listing
or screenshot changes are authorised by the research recommendation.

Before implementation, establish where the quiz will live and whether it is a separate
experience outside the schedule product. Embedding wider quiz content in No Spoilers
requires an explicit scope/rules decision. Preserve the existing trademark disclaimer;
do not introduce series-owned names, marks, logos or imagery on product/listing surfaces.

## Acceptance, evidence and remaining work

### Local dataset result

The user requested local datasets to avoid repeated queries. Built a pinned
[F1DB v2026.21.0](https://github.com/f1db/f1db/releases/tag/v2026.21.0) SQLite snapshot
and 17 CSV exports at the gitignored `research/quiz-data/`. See the durable
[local data inventory and definitions](../docs/christmas-quiz-data.md). Coverage runs
from March 2000 through Las Vegas on 22 November 2026. The original upstream database
also retains earlier history and future calendar entries; the quiz exports are filtered.

The source archive, licence, release metadata and actual schema are retained locally.
Each CSV has saved SQL, and the manifest includes checksums, row counts and attribution.
Read-only offline queries now cover drivers, countries, circuits, race and qualifying
results, separate Sprints, standings, pit stops, fastest laps and nationality outliers.
No app inputs, models, resources, tests or build paths changed.

Searched project scripts and Python/shell files across sibling workspaces for F1DB,
Jolpica and quiz-data acquisition/export mechanisms; none was found. Kiwix hits were
the existing mirror operations, which remain the Wikipedia access mechanism. The
small ad hoc local exporter is under `tmp/ad-hoc-scripts/`, uses Python stdlib SQLite
and CSV rather than a new HTTP client, and has no network calls. There is no existing
Python structured logger in this project's scripts; the ad hoc exporter uses fixed
JSON audit events with timestamp, severity and traceback at its boundary, rather than
copying older scripts' console-output patterns. Only input/output paths and operation
metadata enter the log; result data stays in the ignored research directory.

Checks: archive SHA256 matched the release asset digest; extracted database hash matched
the file inside the verified ZIP; SQLite integrity returned `ok` and foreign-key checking
returned no violations. The era contains 524 race IDs and 11,024 unique race/driver rows,
with exactly one winner per race. The exports contain 132 drivers and 39 circuits.
CSV line counts matched the manifest's 17 row counts plus headers. The builder rejected
an incorrect archive digest and an existing output directory with exit status 1, preserved
the original exports, and left no failed-build output or staging directory. These local
checks were run serially. A second successful build into a temporary directory produced
byte-identical CSV and SQL files; only manifest build time differed. IDE inspection could not resolve the ignored ad hoc script;
its successful execution is the Python syntax/runtime evidence. No app tests or builds
were needed or run.
Completed-year nationality counts reproduce the earlier Finland/Germany comparison,
but the user rejected that question as confusing: question 6 is retired as a candidate.
The local singleton analysis instead finds two countries with exactly one victory in
2000–2025. This is a lead for the next question, not an approved replacement.

Independent read-only review found no substantive issues: it verified the 17 CSV
checksums and row counts against the manifest, reconciled four exports with saved SQL,
checked source provenance and documented missingness, and reviewed the updated builder's
read-only access, lock, staged publication and failure handling. It confirmed that the
ignored research paths sit outside app resource boundaries. The reviewer ran no tests
or builds. The local-data step is complete; the broader quiz task remains open.

- [x] Document a varied shortlist with direct links, topic coverage, access method and
  known reuse restrictions or explicitly unverified permissions.
- [x] Include our Wikipedia mirror, structured data, official records, biographies, rules, circuit operators,
  team heritage and independent references in the catalogue above.
- [x] Identify a leading data candidate and distinguish data licensing from code licensing.
- [x] Record the conflict with the current schedule-only product boundary before implementation.
- [x] Confirm the question era (2000 onward) and the user's preference for fun, obscure trivia,
  outliers and weird statistics.
- [x] Save the first user-approved multiple-choice question, answer, explanation and
  checked sources in the question bank. This is editorial material, not app input.
- [x] Save the user-approved second multiple-choice question, naming Markus Winkelhock,
  from a sourced statistics table: the five
  lap leaders at the 2007 European Grand Prix. Check the lap ranges and 60-lap total;
  corroborate the unusual one-race career through a driver interview and official editorial.
- [x] Draft three current-season questions with their sources: Verstappen's Mario Kart
  comparison, the Las Vegas lap-end leadership statistic, and the Antonelli/Alonso birth-year
  connection. Questions 3 and 4 remain drafts.
- [x] Replace question 5 with the user's approved exact-date version: Alonso had one title
  when Antonelli was born. Record the birth-date and contemporary title-report sources.
- [x] Replace the rejected current-season nationality-points question with a historical
  candidate: Finland and Germany each had four different Grand Prix winners in 2000–2025.
  The user requested historical national statistics. Keep the selected five-nation inventory,
  period, metric definition and dated sources beside question 6.
- [x] Build local structured datasets with a pinned source, retained licence, saved queries
  and provenance, independently of the schedule app. Record period and metric limits.
- [x] Draft a simpler nationality singleton as question 10: Venezuela's sole Grand Prix
  podium since 2000 was a win. Retain the four-option comparison table, period and source.
  Add the user-requested optional clue, "The driver was Pastor Maldonado": a correct
  unaided answer earns 1 point; using the clue reduces it to ½ point. Offer it before
  the answer is submitted and disclose the reduced score before revealing the clue.
- [x] Draft a simple greatness comparison from the local dataset: Hamilton's 106 Grand
  Prix wins equal Vettel 53 + Alonso 32 + Räikkönen 21 at the Las Vegas 2026 cutoff.
  The user approved question 7 and requested the title comparison immediately afterward.
  Question 8 asks about the matching title totals, 7 = 4 + 2 + 1; question 7's reveal
  now saves that fact for question 8. Both retain the fixed cutoff and local evidence.
- [x] Draft the requested British-title question as question 9: nine titles since 2000,
  from Hamilton seven, Button one and Norris one, using championship-won flags.
- [x] Draft question 11 from Button's 2009 title season: he last won in June and
  clinched the title in October. Local results split into six wins in the opening seven
  races and zero in the final ten, with 61 + 34 = 95 points. Corroborated the full
  sequence in the official results archive and checked the official biography and
  McLaren retrospective. Added the optional Turkish GP clue and retained a further
  lead: 15 points in the first two 2009 races exceeded 6 + 3 in 2007–2008 combined.
- [ ] Obtain approval of the new wording and independent source corroboration for questions
  7–10 before publication. Local queries verified the calculations; no new web requests,
  app changes or automated tests were needed for these editorial additions.
- [x] Continue the user's requested search with eight new sourced drafts, questions 12–19:
  Vettel's first championship lead at the 2010 finale; Button's six pit-lane visits
  in Canada 2011; Räikkönen handing the 2003 Brazil trophy to Fisichella; seven winners
  in the opening seven 2012 races; Heidfeld's 13 podiums with no wins; Pérez going from
  last after lap one to his first win; Sainz winning 16 days after appendix removal;
  and Bearman scoring for Ferrari and Haas in his first two Grand Prix starts.
  Retain each direct source, checked date and local query definition in the bank.
  Three new questions have optional clues; Sainz's question precedes Bearman's without
  giving away the substitute's name. The Hamilton pair remains consecutive.
  These are drafts for selection, not approved additions to an app.
- [ ] Obtain user approval of questions 11–19 and complete final editorial ordering.
- [x] Investigate the user's four further avenues: close qualifying, last-lap winning
  lead changes, race duration/distance/lap extremes, and most/fewest different seasonal
  winners by driver, constructor and nationality. Save definitions, sources, ties and
  coverage in [Statistical extremes](../docs/christmas-quiz-statistical-extremes.md).
  Build five additional local CSV/SQL tables with their own manifest using the existing
  exporter unchanged; retain a separate six-example sourced last-lap CSV, explicitly
  nonexhaustive. No new acquisition client or app ingestion path was introduced.
  Scope inventory: 524 completed race weekends through Las Vegas 2026 for qualifying
  and race dimensions; all 26 completed seasons 2000–2025 for seasonal extrema,
  with unfinished 2026 held separately. Sources corroborate the Canada 2024 tie,
  the USA 2015 Q2 exception, selected last-lap changes, Spa's final classification,
  Monza's 2025 result, and the 2012/2015 winner inventories.
- [x] Draft questions 20–24 from those findings: Canada's identical qualifying laps,
  Räikkönen's win from 17th with a last-lap pass, Belgium's zero green-flag laps,
  six winning teams in 2012, and only British/German winners in 2015. Each retains
  sources and a checked date; selected questions offer half-point clues.
- [x] Record user approval of question 24 and draft the requested shared-season
  question 26 for 2014, 2015 and 2023. Exactly three different drivers won in each.
  Verify all distractors, especially avoiding "only two teams won", which is also true.
  Record the overlap with the six two-team seasons: the other three had four winning
  drivers; only Ferrari, McLaren, Mercedes and Red Bull won across the six seasons.
  Retain the further locally checked Toro Rosso link among Ricciardo, Vettel and
  Sainz as a lead pending an independent editorial source.
- [x] Add question 25 immediately after question 24: Button is the only non-winner
  among Hamilton, Button, Rosberg and Vettel in 2015. Verify the 10/0/6/3 counts
  locally and retain the official results/standings sources. Move the shared-season
  draft to question 26. Question 24's reveal now withholds winner names, and its clue
  refers to the 2014 title contenders, protecting the follow-up's answer. Question 25
  offers the optional McLaren-Honda clue under the established half-point rule.
- [ ] Obtain user approval of questions 20–23, 25 and 26. Independently corroborate broader
  full-period record claims before converting the research comparison into record questions.
- [x] Investigate the user's team-career avenue, then follow their more specific request
  for a named-team overlap, always since 2000. Draft question 27: only Hülkenberg among
  the four options raced for Williams, Sauber, Force India and Renault. The local
  16-pair CSV/SQL inventory checks every option; Heidfeld and Fisichella each match three,
  Pérez two. The official biography and career retrospective corroborate the winning
  answer's four teams, dates and Haas-2023 clue. Use race appearances and exact named
  constructors, not tests, reserves, engines or merged team lineages. Broader "most
  teams" rankings remain unsuitable without an agreed renaming convention.
- [ ] Obtain user approval of question 27. Retain the easier Alonso four-team set as a lead.
- [x] Audit reliability data already present locally: DNF status, laps and reported
  retirement causes. Retain a status/reason CSV and SQL inventory; distinguish the
  2,117 explicit DNF labels from 253 numbered classifications with a retirement reason,
  and keep non-starts/disqualifications separate. No blanket mechanical-failure
  classification or misleading starts-based rate was added. Draft question 28 from
  Schumacher's complete 2002 season: worst result third, with 11 wins, five seconds
  and one third across 17 races. Check local rows, the official race archive and the
  driver's official site. These edits are editorial; no app tests/builds are needed.
- [ ] Obtain user approval of question 28; explore further reliability questions using
  explicit retirement and mechanical-failure definitions.
- [ ] Confirm quiz host surface, intended audience, final data cutoff and Christmas deadline.
- [ ] Select sources and establish permission for the actual distribution and any media.
- [ ] Continue authoring and independently verifying a varied question pack. Inspect any
  selected release/schema and exact source pages before use; settle product scope before integration.
- [ ] Plan the embedding experience and implementation under the agreed product rules.

Verification for this research: browsed the linked catalogue landing pages and the cited
licence, terms and API documentation; searched existing `tasks/`, `docs/`, `README.md` and
project rules for an existing quiz task/source mechanism and found none there. Read and
reuse the user-supplied sibling workspace's Kiwix documentation for Wikipedia access;
no new research access mechanism is proposed. Read the existing
task format, README architecture and spoiler rules. The initial catalogue pass imported
no datasets; the later local-data step above retains the research snapshot outside the
app. Questions 1, 2, 5, 7 and 24 are approved; questions 3, 4, 8–23 and 25–37 have draft wording,
and question 6 was rejected,
each with source links and checked dates; the second question includes
its research table and source checks. Research counts were checked against the lap-by-lap
leader sequence and recomputed from inclusive lap ranges (47 + 6 + 5 + 1 + 1 = 60).
The single-race career was corroborated separately; 100% means one race led in one start,
not a share of laps or an official pole. The Las Vegas lap-end table gives 45 + 4 + 1 = 50;
35 reported lead changes is a separate measure, not a count of lap-end leader changes.
The FIA transcript supplies the Mario Kart comparison directly. The revised fifth question
uses Antonelli's official birth date (25 August 2006) and the contemporary report of Alonso's
second title (22 October 2006). The historical nationality analysis filters dated Grand Prix
wins to 2000–2025 and counts each driver once: Germany 4, Finland 4, France 2, Brazil 2,
Netherlands 1. The question bank contains the 13-name inventory for those five nations,
not a claim to cover every nation. The official Bottas milestone article corroborates
the Finnish winner list; pre-2000 winners are excluded by the dated national win records.
These changes affect Markdown only; app builds and automated
tests are not needed. Retain this task while the planned quiz work remains.

For questions 12–19, local verification checked all 19 post-race Vettel standings
in 2010 (first place only at round 19), Button's six Canada pit records and official
race duration, the seven named opening winners in 2012, Heidfeld's eight seconds and
five thirds, the final Brazil 2003/Sakhir 2020/Australia 2024 results, and Bearman's
chronologically first two results. Published sources supply the intermediate running
orders, trophy ceremony, surgery and substitution details that the classification
database cannot establish. The Canada question says six pit-lane visits including
the penalty, not six tyre stops; the Vettel question says official post-race rank,
including tiebreakers. Avoided stale claims elsewhere in older record articles and
the loose time estimate in the trophy retrospective. Sources include official race
reports, interviews, the results archive, McLaren's detailed team account and ABC's
contemporary reporting of Sainz's withdrawal.
No app files, builds or automated tests were involved; Markdown diff checks passed.

The statistical-extremes investigation reused the existing exporter and pinned source.
Its five CSV exports have 524 qualifying pairs, 524 race-dimension rows, 26 completed
season rows, one 2026 snapshot row and 137 season/driver/constructor winner rows.
CSV line counts agree with the manifest plus headers. USA 2015's explicit Q2 exception
is corroborated by its contemporary report; the other timing rows use Q3 or their
legacy classification time. Every pair has comparable timing data, with no negative
gaps. The six curated last-lap examples have matching final winners in the database;
their lead-change mechanisms come from the separately cited reports.

Independent read-only review found no substantive issues. It reconciled all five
exports with saved SQL and checked their hashes and counts; recomputed qualifying
coverage, race extrema, seasonal minima/maxima with tied years and 2012 constructor
totals; and independently corroborated the 2015 win counts/nationalities against
the official archive. It reviewed questions 20–24's unique answers, sources and metric
distinctions. No new helper, network client or app mechanism was introduced. Neither
the author nor reviewer ran app tests or builds for this research. Markdown diff
checks passed; the broader authoring task remains open.

The reliability extension reuses the pinned SQLite source and existing SQL/CSV
evidence convention, with no new helper or provider. Its local constructor-season
ranking contains 274 rows for completed seasons 2000–2025 with at least 20 car
starts. McLaren 2024 has the lowest recorded all-cause retirement rate (1/48),
Prost 2000 the highest (23/33). Explicit non-starts are excluded; late classified
retirements are included; DSQ does not itself imply retirement. Treating all
13 cause-less NC results as retirements leaves both extrema unchanged. The
selected seasons have no NC ambiguity. The 236-row case-study export preserves
the raw statuses and causes, including Prost's pre-race exclusion and Norris's
classified Austria retirement. Questions 30–31 use matching all-cause definitions;
McLaren's zero mechanical failures is a separate, team-corroborated reveal fact.
Question 29 pairs Verstappen's 2023 worst finish (fifth) with Schumacher's 2002
question. Sources and checked dates are recorded per question. Brawn's two 2009
retirements and Hamilton's carefully qualified 62-appearance sequence remain
research leads. No app code or data changed; no app tests or builds are needed.
Independent read-only review found no substantive issues: both CSVs reconciled
exactly with their saved SQL, the retirement extrema survived the NC sensitivity
check, and official archives corroborated the selected retirement totals and
Verstappen's 19/2/1 distribution. Question denominators, unique answers and reuse
of the existing evidence mechanism were checked. Markdown diff checks passed.

Question 32 adds a reliability oddity: Pérez returning to Japan 2023 specifically
to serve his later five-second penalty, then retiring again. The official series
report establishes the sequence; Sky's contemporary explanation and Horner interview
establish the concern about a possible next-race grid penalty. The local result and
official classification agree on one DNF and 15 completed laps, not two statistical
retirements. The question avoids inconsistent lap-reference details and does not
describe a grid drop as automatic. Source links, checked date and an optional
Qatar clue are retained. Markdown-only addition; no app tests or builds required.

Question 33 supplies an alternative to question 13 after the user recalled
Button's wet Montreal comeback. The event was 2011, not his 2009 title season.
McLaren's account explicitly places him 21st and last on laps 37–40; the official
result and cached database confirm the 70-lap race and 4:04:39.537 winning time.
The new question asks his position with 30 laps left. Both alternatives are marked
for final selection rather than using reveals that spoil one another. Confirmed
collisions and Vettel's final-lap error are retained; no unverified Button spin
count is asserted. Sources rechecked 2026-11-24; Markdown diff checks passed.

Question 34 adds Hamilton's lone grid restart in Hungary 2021: one car on the
grid while 14 rivals switched to slick tyres and restarted from the pit lane.
Contemporary official reporting supplies the driver/race-director accounts;
Pirelli's Sunday report corroborates the tyre choices and adds a tyre-supplier
source to the pack. The prompt explicitly counts restart-grid cars, not race
participants. Source links and checked date are recorded; no all-time uniqueness
claim is made. Markdown-only work; no app tests or builds required.

Question 35 adds a different kind of retirement: Räikkönen watching the rest of
Monaco 2006 from a yacht after his McLaren fire. Official series coverage and
Goodwood's chassis retrospective agree on the yacht episode; the cached database
confirms DNF, 50 completed laps and `Fire`. Avoided the official retrospective's
incorrect opening-laps description and unneeded yacht-ownership details. Sources
and checked date recorded; Markdown diff checks passed. No app tests or builds
are required for this editorial addition.

Question 36 returns to statistical oddities: Hamilton won ten races in 2016
but lost the title to Rosberg, who won nine. The four-candidate comparison is
saved locally as SQL/CSV using the existing evidence convention: maxima in
non-title seasons during 2000–2025 are Hamilton 10, Räikkönen 7, Massa 6 and
Alonso 5. Official season statistics and the FIA finale report corroborate the
Hamilton/Rosberg story. The clue supplies 2016; wording distinguishes losing
that season's title from never becoming champion. Source dates and provenance
are recorded. Markdown diff checks passed; no app tests or builds are required.

Question 37 returns to rare nationalities: Portugal's sole GP podium since
2000 came through Monteiro in the six-starter USA 2005 race. Reused the existing
nationality export; checked the single dated Portuguese podium and six numerical
results plus 14 DNS rows in the pinned database. Official results corroborate
the podium, and contemporary reporting explains the Michelin withdrawals.
Distractors use the same four-country inventory as question 10; the optional
half-point clue supplies Monteiro's name. The fixed Las Vegas 2026 cutoff and
actual-start versus formation-lap distinction are explicit. No new data feed,
helper or app changes; Markdown diff checks passed, with no app tests needed.

Independent read-only reviews found no substantive issues. The reviewer independently
retrieved the FIA and official series passages, checked question 5's exact dates, and
reviewed the historical question's metric, fixed period and 13-name inventory. It
independently checked the official Finnish winner list and Häkkinen's qualifying
2000/2001 victories. The national win logs returned error pages through the reviewer's
command-line access; the authoring agent checked their dated rows, unique names and
exclusion boundaries through the web tool. For question 4,
STATS F1 returned HTTP 404 through its command-line retrieval, so its review of that
lap-end table relied on the authoring agent's successful web retrieval of the summary
and all 50 lap rows. Source availability differs by access route; the lap-range
calculations were checked separately.
