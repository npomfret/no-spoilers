# Christmas quiz: statistical extremes

Private editorial research, checked 24 November 2026. Subject matter starts in 2000.
This supports the [question bank](christmas-quiz-questions.md), outside the schedule app.

The quantitative base is the pinned [F1DB v2026.21.0 release](https://github.com/f1db/f1db/releases/tag/v2026.21.0),
through Las Vegas on 22 November 2026. Five additional offline tables, their SQL and
checksummed manifest are at `research/quiz-data/extremes-v2026.21.0/`; the explicit
configuration is `research/quiz-data/build-extremes.json`. The existing local exporter
was reused unchanged. See the [dataset guide](christmas-quiz-data.md) for provenance.

| Local table | Rows | Grain |
| --- | ---: | --- |
| `qualifying_front_pair_times_2000_plus` | 524 | First two classified qualifiers per completed Grand Prix weekend |
| `race_time_distance_laps_2000_plus` | 524 | Official winning time, classified distance and laps per Grand Prix |
| `season_winner_diversity_2000_2025` | 26 | One row per completed season |
| `season_winner_diversity_2026_snapshot` | 1 | Unfinished 2026 season, kept separate |
| `season_winning_driver_teams_2000_plus` | 137 | Wins per season, driver and constructor combination |

## Extremely close qualifying

The smallest gaps between the first two classified qualifiers in the local era:

| Year | Grand Prix | First qualifier | Second qualifier | Times | Gap |
| --- | --- | --- | --- | --- | ---: |
| 2024 | Canada | George Russell | Max Verstappen | 1:12.000 / 1:12.000 | 0.000 s |
| 2006 | Italy | Kimi Räikkönen | Michael Schumacher | 1:21.484 / 1:21.486 | 0.002 s |
| 2010 | Germany | Sebastian Vettel | Fernando Alonso | 1:13.791 / 1:13.793 | 0.002 s |
| 2000 | Great Britain | Rubens Barrichello | Heinz-Harald Frentzen | 1:25.703 / 1:25.706 | 0.003 s |
| 2023 | Hungary | Lewis Hamilton | Max Verstappen | 1:16.609 / 1:16.612 | 0.003 s |

Best question lead: Russell and Verstappen tied to the recorded thousandth, but Russell
got pole because he set the time first. Norris was only 0.021 s behind them in third.
The [FIA's contemporary qualifying report](https://api.fia.com/news/f1-russell-claims-pole-canadian-grand-prix-verstappen-sets-identical-lap-time)
confirms the times, order and tiebreak. The [official Italy 2006 qualifying table](https://www.formula1.com/en/results/2006/races/804/italy/qualifying)
also independently confirms the 0.002 s example.

Definitions matter:

- Compare times from the decisive qualifying stage, not each driver's fastest lap
  across stages. A Q2 time can be quicker than Q3 and still not decide pole.
- The export uses Q3 when both front qualifiers have Q3 times, otherwise the legacy
  classification time. It has one explicit, corroborated exception: USA 2015 uses Q2
  because Q3 was cancelled. The [contemporary report](https://www.formula1.com/en/latest/article/rosberg-on-pole-in-austin-after-rain-curtailed-qualifying.74wg9TQFZCQWoRXPzlYAlm.74wg9TQFZCQWoRXPzlYAlm)
  confirms 1:56.824 and 1:56.929. It does not silently substitute an earlier phase.
- Six weekends have `qualifying_format = 'SPRINT_RACE'`. Their timed qualifying
  results are retained with that label; do not equate Friday's fastest qualifier
  with the Sunday pole-sitter. Grid penalties create another distinction between
  qualifying classification and starting position.
- Ties mean equal recorded times at millisecond precision, not a measurement of
  an unrecorded smaller difference. The famous 1997 Jerez triple tie is outside our era.

## Wins decided on the final lap

These are six verified examples, **not an exhaustive list or a basis for a record count**.
The curated local CSV is `research/quiz-data/last-lap-examples-checked-2026-11-24.csv`,
with event keys, mechanism, source URL and checked date. The classifications database
can confirm the final winner; it cannot establish a final-lap lead change.

| Event | Winner | Displaced leader | What happened on the last lap | Evidence |
| --- | --- | --- | --- | --- |
| Spain 2001 | Michael Schumacher | Mika Häkkinen | Häkkinen lost drive with a clutch failure | [F1 retrospective](https://www.formula1.com/en/latest/article/do-you-remember-hakkinens-dramatic-last-lap-retirement-in-spain.5KrvEuDAHppTbmEDbiFXOn) |
| Europe 2005 | Fernando Alonso | Kimi Räikkönen | Räikkönen's front suspension failed | [Contemporary Autosport review](https://www.autosport.com/general/news/the-2005-european-gp-review-5076445/5076445/) |
| Japan 2005 | Kimi Räikkönen | Giancarlo Fisichella | Pass around the outside into Turn 1 | [F1 retrospective](https://www.formula1.com/en/latest/article/moments-in-time-the-japanese-grand-prix.5M4HpgAHNmMjn15iW7nAXO.5M4HpgAHNmMjn15iW7nAXO) |
| Canada 2011 | Jenson Button | Sebastian Vettel | Vettel's mistake allowed Button through | [McLaren account](https://www.mclaren.com/racing/heritage/how-button-won-the-2011-canadian-grand-prix/) |
| Austria 2016 | Lewis Hamilton | Nico Rosberg | Contact during the challenge, then Hamilton passed | [FIA race report](https://www.fia.com/news/f1-hamilton-wins-austria-after-last-lap-collision-rosberg) |
| Abu Dhabi 2021 | Max Verstappen | Lewis Hamilton | Pass on the last lap after the Safety Car restart | [FIA race report](https://www.fia.com/news/f1-verstappen-takes-formula-1-drivers-title-victory-dramatic-abu-dhabi-grand-prix) |

Best lead: Räikkönen started **17th** in Japan and made the winning pass on the final
lap. Do not claim he led only that lap: a final-lap pass does not exclude earlier
leadership during pit-stop cycles. The local race result confirms the starting position.

For authoring, separate an on-track pass from inheriting the lead after a retirement.
Likewise, a last-lap championship decision is not necessarily a last-lap change of race
winner. Source details need checking: the Spain retrospective misnumbers the final lap,
while the local final result records 65 laps. Use its last-lap narrative, not that number.

## Shortest and longest races

These are different measures, all filtered to the local 2000-onward snapshot:

| Measure | Event | Value | Qualification |
| --- | --- | --- | --- |
| Shortest official winning time | Belgium 2021 | 3:27.071 | A curtailed event behind the Safety Car; no green-flag racing |
| Longest official winning time | Canada 2011 | 4:04:39.537 | Includes the long rain suspension |
| Smallest classified distance | Belgium 2021 | 6.880 km, one classified lap | Countback classification; not the total distance driven that afternoon |
| Largest classified distance in F1DB | Japan 2000 and 2001 | 310.580 km | Local distance finding; not yet independently corroborated for a question |
| Most classified laps | Sakhir 2020 | 87 | Short outer-loop layout; not the usual Bahrain circuit configuration |
| Highest average winning speed | Italy 2025 | 250.706 km/h | Calculated from 306.720 km and 1:13:24.325 |

The [FIA's final Belgium classification](https://www.fia.com/sites/default/files/doc_43_-_2021_belgian_grand_prix_-_final_race_classification.pdf)
explicitly states one lap, 6.880 km and 3:27.071. The
[official race report](https://www.formula1.com/en/latest/article/verstappen-takes-victory-in-severely-shortened-rain-affected-belgian-gp-as.4AqGhiKQfFaqr7KZjyDjPZ)
explains the Safety Car running and half points. That afternoon's waiting time is
not the official winning time. Do not turn the classified one lap into a claim that
the cars circulated only once in total.

Canada's elapsed winning time is corroborated by the sources for question 13.
The [FIA's Italy 2025 report](https://www.fia.com/news/f1-verstappen-wins-f1s-fastest-race-monza-ahead-norris-and-piastri)
corroborates the winner, 53 laps and time and describes it as F1's fastest race.
The speed above is our calculation: distance / winning time, converted to km/h.
Fastest average speed is not the same record as shortest official duration.

Avoid ranking a vague "shortest race" without specifying distance, laps or duration.
Do not mix official winning time, green-flag time and total event wall-clock time.

## Different winners in a season

The inventory for this comparison is the 26 rows in
`season_winner_diversity_2000_2025.csv`, covering each completed season from 2000
through 2025. The 2026 partial season is a separate table and excluded from these extrema.
Every Grand Prix has one final classified winner in this dataset; Sprints are excluded.

| Measure | Most | Seasons attaining most | Fewest | Seasons attaining fewest |
| --- | ---: | --- | ---: | --- |
| Different winning drivers | 8 | 2003, 2012 | 3 | 2014, 2015, 2023 |
| Different winning constructors | 6 | 2012 | 2 | 2000, 2007, 2014, 2015, 2016, 2023 |
| Different winning nationalities | 7 | 2003 | 2 | 2015 |

Count each identity once within each season. Teams mean constructors, not engine
suppliers, sponsors or team ownership lineages. Nationality means F1DB's primary
driver nationality, not birthplace or the host country; Nico Rosberg counts as German.
The saved detailed winner table supplies the driver/constructor/country inventory.

Some promising contrasts:

- **2003 and 2012 tie at eight winning drivers**, although their calendars contained
  16 and 20 Grands Prix respectively.
- **2012's six winning teams:** Red Bull, McLaren, Ferrari, Mercedes, Williams and
  Lotus. Their win counts are 7 + 7 + 3 + 1 + 1 + 1 = 20.
- **2003's eight winning drivers represented seven nations:** Michael and Ralf
  Schumacher were both German; the others were Coulthard (British), Räikkönen
  (Finnish), Fisichella (Italian), Montoya (Colombian), Barrichello (Brazilian) and
  Alonso (Spanish).
- **2015's 19 races had winners from just two nations:** Hamilton won ten for
  Britain; Rosberg six and Vettel three for Germany. British wins 10, German wins 9.
- The fewest-winning-drivers record has three seasons tied. Do not offer a question
  with two of those years as separate options and expect a unique answer.

The [official 2012 race archive](https://www.formula1.com/en/results/2012/races)
corroborates the six constructors and their wins. The
[2015 race archive](https://www.formula1.com/en/results/2015/races) and
[2015 driver standings](https://www.formula1.com/en/results/2015/drivers) independently
corroborate that year's win counts and nationality grouping. The full min/max table is a calculation
from the pinned dataset, not a claim that all 26 seasons were separately checked against
another publisher. Further independent corroboration is needed before publishing a
global record question based on the whole comparison.

### Overlap between the two-team and three-driver seasons

The three seasons with only three winning drivers are exactly half of the six
seasons with only two winning teams. In the other three, both winning teams had
two winning drivers.

| Season | Winning constructors | Different winning drivers |
| --- | --- | ---: |
| 2000 | Ferrari, McLaren | 4 |
| 2007 | Ferrari, McLaren | 4 |
| 2014 | Mercedes, Red Bull | 3 |
| 2015 | Mercedes, Ferrari | 3 |
| 2016 | Mercedes, Red Bull | 4 |
| 2023 | Red Bull, Ferrari | 3 |

Across all six seasons there are only **four** winning constructors in total:
Ferrari, McLaren, Mercedes and Red Bull. Ferrari/McLaren and Mercedes/Red Bull
each recur twice; Mercedes/Ferrari and Red Bull/Ferrari occur once each.

For a useful reveal after the shared-season question, the only winning driver
outside the dominant team was Ricciardo in 2014, Vettel in 2015 and Sainz in 2023.
Do not use the two-team fact as an incorrect option in a three-season question:
both it and the three-driver statement are true. These overlaps were calculated
from the saved detailed winning-driver/constructor table, not inferred from
constructors' championship positions.

A further connection worth checking for a future question: the local race-result
history shows that all three outsiders raced for Toro Rosso earlier — Vettel in
2007–2008, Ricciardo in 2012–2013 and Sainz in 2015–2017. This was checked by
filtering those driver IDs to `constructor_id = 'toro-rosso'` and taking their
first/last race years. Retain as a lead pending independent editorial corroboration.

## Drivers who raced for the same set of teams

Prefer named-team overlap to a "most teams" record, since team renames and ownership
changes make raw constructor-label counts ambiguous. Use Grand Prix race appearances
since 2000, with test and reserve-only roles excluded. Treat each named constructor
literally rather than merging engine suppliers or historical team lineages.

The strongest checked set is **Williams, Sauber, Force India and Renault**. Hülkenberg
matches all four. Heidfeld matches three but not Force India; Fisichella matches three
but not Williams; Pérez matches Sauber and Force India. The complete 16-pair inventory
and saved query are at `research/quiz-data/questions/hulkenberg-team-overlap.csv` and
`.sql`, using the pinned snapshot and the 2000-through-Las-Vegas-2026 cutoff. Each
positive match has completed race laps; the four negative matches have no result entry.
Question 27 retains the matrix, dates, source links and optional Haas-2023 clue.

An easier alternative set, checked locally as a lead: **Ferrari, McLaren, Renault and
Aston Martin** matches Alonso. Among Sainz, Vettel and Ricciardo, none matches all four:
Sainz has the first three; Vettel Ferrari/Aston Martin; Ricciardo McLaren/Renault.
Retain for later selection rather than adding another similar question immediately.

## Reliability and did-not-finish statistics

The existing local `race_result` view and `gp_results_2000_plus.csv` already contain
`position_text`, `position_number`, `laps` and `reason_retired`. No new external
data is needed to explore retirement counts by driver, constructor, season or race,
or to inspect the provider's reported causes. The audit query and CSV are retained
at `research/quiz-data/questions/retirement-status-audit.sql` and `.csv`.

Across the 11,024 result rows since 2000 through Las Vegas 2026:

- 2,117 rows explicitly have `position_text = 'DNF'`; each has a reported reason.
- 253 rows have a numeric classified position and a non-null retirement reason.
  For example, Häkkinen was classified ninth in Spain 2001 despite his last-lap
  clutch failure. Bourdais and Räikkönen were classified seventh and eighth in
  Australia 2008 with engine failures recorded.
- DNS, DNQ, DNP, EX, NC and DSQ are separate source statuses; preserve them.
  A non-start or disqualification is not automatically a race retirement.
- Reasons include Engine, Gearbox, Hydraulics, Brakes, Collision, Collision damage,
  Accident and Spun off. DNF is not a synonym for mechanical failure; keep the
  original categories instead of silently treating every retirement as car unreliability.

Do not infer "finished running" just from a numbered classification, or build a
reliability rate using result entries as if they were race starts. A published
mechanical-failure rate needs an explicit cause classification and a checked
denominator. Finish/retirement streaks also need a decision about non-starts and
late classified retirements before they can support a record claim.

A clean question avoids those ambiguities: Schumacher's 2002 season contained
11 wins, five seconds and one third, with no retirement reasons or DNF labels.
His worst result was third. Question 28 records the full-season check and
corroboration from the official results and his own site's season summary.

### Most and least: comparing team seasons

Use **retirements per car start**, including crashes and late classified
retirements. This measures retirement frequency, not purely mechanical reliability.
Compare completed seasons **2000–2025**, with at least **20 car starts** per
named constructor-season. Keep 2026's unfinished season out of this comparison.
No constructor-lineage merging is needed for a single-season comparison.

The saved query and complete 274-row ranking are
`research/quiz-data/questions/team-season-retirements.sql` and `.csv`.
They reuse the pinned local database rather than another results feed.

| End of ranking | Team and season | Car starts | Recorded retirements | Retirement rate |
| --- | --- | ---: | ---: | ---: |
| Lowest | McLaren 2024 | 48 | 1 | 2.083% |
| Next lowest | Ferrari 2021 | 43 | 1 | 2.326% |
| Next lowest | Mercedes 2017 | 40 | 1 | 2.500% |
| Highest | Prost 2000 | 33 | 23 | 69.697% |
| Next highest | Arrows 2000 | 33 | 20 | 60.606% |
| Next highest | BAR 2002 | 34 | 20 | 58.824% |

These extrema are calculations from the pinned source under the stated rules,
not independently published records. Questions 30–31 ask about the two selected
seasons directly and retain their corroborating sources.

The denominator excludes explicit DNS, DNQ, DNP, DNPQ and EX statuses. DSQ
starters stay in it; disqualification itself is not a retirement. The numerator
counts non-null retirement causes, excluding DSQ. The 13 completed-era NC rows
have no cause: expose their count separately and calculate a second rate treating
all of them as retirements. The lowest and highest constructor-seasons are
unchanged under that sensitivity check. Neither selected season has an NC row.
Do not infer non-starts from missing lap counts: some DSQ starters have null laps.

The selected cases have an additional independent check:

- **McLaren 2024:** [the team's MCL38 profile](https://www.mclaren.com/racing/heritage/formula-1/cars/2024-formula-1-mclaren-mcl38/)
  reports no mechanical failures during any GP or Sprint. Its sole recorded GP
  retirement was Norris's Austria collision damage, despite being classified 20th.
- **Prost 2000:** the official [Alesi](https://www.formula1.com/en/results/2000/drivers/JEAALE01/jean-alesi)
  and [Heidfeld](https://www.formula1.com/en/results/2000/drivers/NICHEI01/nick-heidfeld)
  archives corroborate 23 retirements. [Contemporary reporting](https://www.autosport.com/f1/news/prost-reveals-why-heidfeld-was-disqualified-5031230/5031230/)
  confirms Heidfeld could not start the European GP. There were 34 entries but
  33 starts, and 22 DNF labels plus one classified retirement in F1DB. Reported
  causes include 17 component/technical labels and six collision/spin labels;
  those component labels alone do not establish whether damage caused a failure.

### Further reliability leads

The 236-row `research/quiz-data/questions/reliability-case-studies.csv` and matching
SQL retain the selected McLaren/Prost seasons alongside these cases:

- **Verstappen 2023:** 22 results, 19 wins, two seconds, one fifth, no retirements.
  Question 29 follows Schumacher's question 28. Corroborated against the
  [complete official driver results](https://www.formula1.com/en/results/2023/drivers/MAXVER01/max-verstappen).
- **Brawn 2009:** 34 starts, only two retirements: Barrichello's Turkish gearbox
  failure and Button's Belgian collision. The official driver archives for
  [Barrichello](https://www.formula1.com/en/results/2009/drivers/RUBBAR01/rubens-barrichello)
  and [Button](https://www.formula1.com/en/results/2009/drivers/JENBUT01/jenson-button)
  corroborate the two retired results. Potential question: how many retirements
  across both cars in the team's entire one-season existence? Answer two.
- **Barrichello 2002:** three DNFs and two DNS results alongside Schumacher's
  uninterrupted podiums. Do not convert his five non-finishes into five DNFs.
- **Hamilton 2018–2021:** local results show 62 classified appearances without
  a retirement cause from Britain 2018 through the Netherlands 2021, bounded
  by Austria 2018 and Italy 2021 retirements. This is 63 calendar events with
  Sakhir 2020 missed, and includes Belgium 2021's Safety-Car-only race. Reserve
  lead, pending primary corroboration and a precise streak definition; do not
  call it 62 consecutive calendar races or an independently verified global record.

All sources in this reliability extension checked 2026-11-24. No app data,
fixtures, product models or outcome-bearing logs were added.
