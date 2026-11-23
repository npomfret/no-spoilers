# Task 08: Christmas Quiz — Facts, Trivia and Data Sources

**Status:** Source research complete; quiz scope and implementation remain planned.
**Sources checked:** 2026-11-23.
**Target:** Christmas 2026, assumed from the request; delivery date and host surface are unconfirmed.
**Question era:** 2000 onward, inclusive (confirmed by the user).
**Editorial direction:** Fun, creative questions about oddities, outliers, little-known
trivia and surprising statistics (confirmed by the user).
**Question format:** Four-option multiple choice, following the first approved question.
**Question bank:** [Christmas quiz questions](../docs/christmas-quiz-questions.md).

## Purpose and scope

Find a varied set of reliable sources for an embedded motorsport quiz covering drivers,
results, circuits, teams, cars, rules and unusual history. The user specifically wants a
variety of sources, so a statistics database alone is insufficient. This task records
source discovery and suitability; it does not implement a quiz or import question data.

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
- [x] Draft a second multiple-choice question from a sourced statistics table: the five
  lap leaders at the 2007 European Grand Prix. Check the lap ranges and 60-lap total;
  corroborate the unusual one-race career through a driver interview and official editorial.
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
task format, README architecture and spoiler rules. No API result payloads or datasets
were imported. The question bank contains one approved question and a second draft with
its research table and source checks. Research counts were checked against the lap-by-lap
leader sequence and recomputed from inclusive lap ranges (47 + 6 + 5 + 1 + 1 = 60).
The single-race career was corroborated separately; 100% means one race led in one start,
not a share of laps or an official pole. These changes affect Markdown only; app builds and automated
tests are not needed. Retain this task while the planned quiz work remains.
