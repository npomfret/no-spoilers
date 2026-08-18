# Factoring an app onto a design system

*Notes from retrofitting a token layer and a shared component boundary onto a small
multi-target Apple app — 49 commits, 47 files, ~4,000 lines added and ~1,400 deleted,
zero UI tests in the repo when it started.*

The app in question ships four surfaces from one codebase: a phone app, a menu-bar
utility on the desktop, four widget families, and a marketing website. Yours will differ
in the details. The failure modes won't.

---

## 0. The premise: pick a falsifiable test before you write anything

The work started from one sentence:

> Change the accent colour, the type scale, the corner radii, the spacing rhythm, the
> motion, and the icon set — one edit each — and have every surface follow.

That sentence is the whole point of the exercise, and it is worth more than any amount of
"improve consistency" framing, for three reasons:

1. **It is falsifiable.** At any moment you can say which of the six pass and which don't.
2. **It scopes by outcome, not by file.** It does not say "clean up `ContentView`". It says
   what must become true, which lets the work go wherever it needs to.
3. **It kills gold-plating.** Anything that doesn't move one of the six is out.

At the start, exactly one of the six passed (colour, partly). At the end all six passed.
That's the report.

**Anti-pattern: "let's introduce a design system" as a goal.** A design system is a means.
Without a test sentence you get a `Theme` file that half the code uses, which is strictly
worse than no `Theme` file because now there are two idioms instead of one.

---

## 1. Count first. The inventory is the plan.

Before any design work, one pass produced raw counts across the product source:

```
88  .font(…)          call sites, none referring to a shared scale
59  .padding(…)       call sites, 57 of them numeric literals
69  spacing: <int>    literals
21  .opacity(…)       literals
11  .system(size:)    absolute point sizes
 0  spacing, radius, typography, motion, or icon constants anywhere in the repo
```

Plus a table of duplicated components (one row was rendered by **four** separate
implementations), and a table of literals-by-meaning: which magic number appeared at how
many sites and what it was standing in for.

Three things fell out of the counting that would not have fallen out of reading:

- **The website was better factored than the app.** The CSS already had custom properties
  for the palette, a radius, and named surfaces (`--card`, `--border`, `--bg`) — roles the
  Swift side did not have at all. That reversed the direction of travel on naming: the
  Swift vocabulary was taken *from* the CSS rather than invented and then back-ported.
- **The same intent had four different values.** A "quiet tint" was `0.08`, `0.10`, `0.12`
  and `0.15` depending on which file it was typed in. Nobody decided that; four people-days
  apart decided it four times.
- **Opacity, motion and iconography were invisible categories.** Nobody lists "we have no
  motion vocabulary" as a problem until they count three inline durations in one file and
  find that nothing else in the product animates at all.

The counts also become the acceptance criteria. At the end:

| | was | now |
| --- | --- | --- |
| `.font(…)` not from a shared scale | 88 | 35, each a token definition or a documented literal |
| `.padding(…)` numeric literals | 57 | 9 |
| `spacing:` literals | 69 | 2 |
| off-grid strays | 11 | 0 |

**Technique: keep the "documented literal" escape hatch, and make it expensive.** 35 is not
0 and was never going to be. A literal that carries a comment saying why it isn't a token
is fine. A literal with no comment is a bug. The count that matters is the second one.

---

## 2. Sequence so that risk starts late and each phase is separately revertable

The order used, and why it is the right order in general:

1. **Add the tokens, unused.** Values transcribed from what is on screen today. Nothing
   consumes them. Zero behavioural risk.
2. **Strings and formatters.** Deduplicate shared copy and formatting rules. Covered by
   existing unit tests; no pixels move.
3. **Semantic state colours** — the first visible change, alone, on its own commit.
4. **Component convergence**, one component per commit, biggest payoff first.
5. **Sweep the call sites onto the tokens**, one target per commit.
6. **The system/asset-catalog level** (accent colour, things the token layer can't reach).
7. **The website.**
8. **The spec document**, last, so it describes what was built rather than what was planned.

The properties that make this ordering work:

- **Phases 1–2 are pure additions.** They can land, sit, and be reviewed while the design
  questions are still open. This matters more than it sounds: the token file becomes the
  place the open questions get *written down* while phases 3–5 are still being argued.
- **The sweep comes after convergence, not before.** Sweeping first means editing the same
  call sites twice — once to name the constant, once to delete the whole implementation.
- **Merging the "which surface am I on" axis is its own phase, before the sweep**, for the
  same reason: the sweep reads that parameter at nearly every site it touches.
- **The spec is written last.** A spec written first is a wish list. Written last, every
  line in it has a call site.

**Technique: one commit per component, and each commit deletes what it replaces.** No
migration period, no "old and new coexist for a sprint". If the convergence is wrong you
revert one commit and you are exactly back where you were. If old and new coexist you have
permanently doubled the surface area and someone will add a call site to the old one.

---

## 3. The token layer: design decisions that held up

### 3.1 Static constants beat environment injection, if your reskin is rebuild-time

The decision was made explicitly and up front: **is the reskin rebuild-time or runtime?**
Rebuild-time. That single answer removed a large amount of machinery:

- No environment keys, no view modifiers, no injection at the root of each surface.
- No question about what a widget timeline does with a theme (it renders in a separate
  process with no host environment to inherit).
- No question about a menu-bar item hosted from an app delegate outside the view hierarchy.

Those three roots are the giveaway. **An environment-keyed theme has to be re-injected at
every root, and it fails silently at any root somebody forgets** — the view just gets the
default. With static constants there is no root and nothing to forget.

**Write down the revisit condition.** "If a runtime theme switch is ever wanted, this
decision gets rewritten, not extended." That sentence lives in the source. It is honest
about the cost and it stops the next person re-litigating it from scratch.

### 3.2 Name the roles now with one value each; don't build variant machinery

Dark mode was explicitly out of scope. The tempting conclusion — "so don't bother with
semantic colour roles yet" — is wrong, and the reasoning is worth stealing:

> Replacing system semantic colours with named palette roles is a reskin blocker on its own
> merits: a system colour does not move when the palette moves. Adding dark mode later then
> becomes "give each role a second value" rather than "find every colour decision again".
> **Do not build a variant mechanism to hold values nobody has chosen** — one value per
> role, and the roles are the seam.

That is the general shape: **the naming is the expensive, irreversible part; the variant
mechanism is cheap and can wait.** Do the expensive part early with the degenerate
one-value case.

### 3.3 One axis for "which surface am I on" — and expect to find three

The plan assumed there were two competing spellings of surface/density. There were three:

| Axis | Cases | Read by |
| --- | --- | --- |
| a `CardDensity` enum | regular / compact / widget | one component |
| a `compact: Bool` parameter | 2 | a shared badge + two private helpers |
| the new `Canvas` enum | 5 | everything the new work added |

Two observations generalise:

**A boolean is an enum that lost information, and it hides drift.** The `compact: Bool` was
concealing a real bug: one screen passed `true` for two badges and passed nothing at all
for a third, so a single row drew two badge sizes. Nobody could see it because `false` and
"not specified" look the same at a call site. Converting the boolean to the surface enum
made the row's inconsistency a compile-visible fact.

**The coarse enum couldn't answer a question the fine one could.** Under the three-case
axis, a component's body text had to be optional, because `.widget` couldn't distinguish
the smallest widget family (no room for a body line) from the two that had room — so the
*view code* computed the absence and passed `nil`. Under the five-case axis the theme
answers it (`showsBody`) and the parameter is required again. **Optionality that exists to
paper over a too-coarse axis is a design smell, not a modelling requirement.**

Concretely: the axis had a case per *surface* (`phoneApp`, `desktopPopover`, `widgetSmall`,
`widgetMedium`, `widgetLarge`), not per *size class*. Two widget families shared a card
geometry and deliberately did not share a type size. A three-case density axis physically
could not express that.

### 3.4 Correlated values belong in one switch, not N parallel switches

Card geometry resolved as **one function returning seven correlated values** (radius,
paddings, shadow, fill opacity, …) rather than seven independent lookups, because a card's
radius is not independently choosable from its padding. If two values must move together,
make it impossible to move one.

### 3.5 Set a bar for adding a token, and enforce it

The rule used: **a typography role is added only once every surface has a real call site to
transcribe.** Not "once we think we'll need it." Two roles qualified in the first pass; the
rest waited, and two more earned their place during the sweep when a fifth call site
appeared.

The corollary is the fail-loud rule: **a role that genuinely does not exist on a surface
must trap there, not return an invented value or an optional.** One canvas had no second
line of text at all; the token for it traps on that case, and the trap is unreachable
because that canvas passes no detail. That is strictly better than inventing a plausible
size, which would silently become real the first time someone added the line.

### 3.6 Delete tokens that lose their last call site, in the same commit

Convergence retired one radius value on the spot: two of three surfaces used 8, one used 10
for the same element, 8 won on majority, and the 10 token had no other site — so it was
deleted in that commit. A token layer accumulates dead entries faster than a codebase
accumulates dead functions, because nothing fails to compile.

---

## 4. Component convergence: the part that actually pays

Tokens are the cheap half. The expensive half is that changing a component means finding
all its copies. Seven convergences landed, one per commit.

### 4.1 Read all N implementations before you write the one

The single most valuable thing here: **the plan was wrong about two of the seven, and both
errors were only visible after reading every copy.**

- A header that looked like "one design at three sizes" was, on reading, **four genuinely
  different designs**. One surface stacked a name under a wordmark; another put three
  elements on one line; the compact widgets drew a single row; the large one stacked. One
  component would have been a switch with four bodies and no shared structure. **Only the
  metadata line actually repeated, and that is the only thing that converged.**
- A footer that the inventory said had four sites had **five** — the fifth was inline in a
  narrow sidebar column with a genuinely different layout, and it correctly did not converge
  either.

**Anti-pattern: converging things that merely look alike.** A shared component whose body
is `switch surface { case a: …; case b: …; case c: … }` with no common structure has bought
you nothing and cost you a level of indirection. The test is whether the *structure* is
shared and only the *values* differ. If the structure differs, converge the sub-part that
doesn't (the metadata line), and leave the rest.

### 4.2 Content stays with the caller; the component owns structure and style

This is what made four session-row implementations collapse into one. The four rows put
genuinely different content on their second line — an absolute date on one surface, a
secondary name on another, a relative time on a third — and genuinely different things in
the trailing slot, from a live countdown to nothing at all.

Had the component tried to own that, it would have needed the surface enum *plus* the
domain model *plus* a formatting policy. Instead it takes `String?` / `View?` slots. The
caller decides what goes there; the component decides how it looks.

**The optional slots also deleted two real bugs.** Two call sites had hidden fallbacks —
`countdown ?? weekend.location` and a formatter that returned the location when a weekend
had no sessions — both drawing a place name where a date or time belonged. Once the
component takes an optional, the honest answer ("there is no second line here") is
expressible, and the fallbacks had nothing left to do.

That is a general result: **hidden fallbacks are often a symptom of a component that
couldn't express absence.** Fix the expressiveness and the fallbacks evaporate.

### 4.3 Convergence forces decisions. Each one is a decision, and each needs a record

Every convergence surfaced a disagreement that had never been decided by anybody:

- Corner radius 8 vs 10 for the same element → **8, on majority**, dead token deleted.
- An eyebrow label red on one surface, grey on two → **grey**, because red is this product's
  *live* signal and the eyebrow marks something that hasn't started. Decided on semantics,
  not on the vote.
- Section-label padding 12/4 vs 10/2 → **12/4**, and the discovery that this was *not*
  platform intent: the screen in question is shared, so both rhythms rendered in the same
  window.
- Vertical padding 8 vs 9 → **8**; both sites were off-grid, and they were the last two.

Note the two different tie-breakers. **Majority is the default; semantics overrides it.**
The red/grey case went against the majority-of-one because there was an actual meaning
attached to the colour. Write down which rule you used, because the next reader will
otherwise assume you just counted.

### 4.4 Watch for the copy nobody counted

The sweep found **a fifth implementation of the session row inside a loading skeleton** —
hand-built with its own accent rule, label stack and panel, still carrying the corner radius
the convergence had retired two phases earlier. Skeletons, placeholders, previews, and empty
states are where duplicate components hide, because they don't look like the component; they
look like grey rectangles.

The fix is the general one: **the skeleton draws the real component**, with placeholder
content, so it cannot drift from what it stands in for. Its placeholder strings became
non-localised verbatim text, because they are shapes, not copy.

---

## 5. Verification when you have no snapshot tests

This is the section worth the most, because it is the situation most teams are actually in.
The repo had unit tests for domain logic and four build wrappers. **None of it covers what
this work changes.** A component convergence that renders the wrong thing compiles and
passes everything.

The gap was named up front as *the largest risk in the task*, and the honest question
— "is a snapshot harness a prerequisite?" — was left open rather than hand-waved.

**It was ultimately answered by removing its premise, not by building the harness.** Here is
the toolkit that replaced it.

### 5.1 Separate compile confidence from behaviour confidence, explicitly

Say which one you have. "All three targets build" is a true and useful statement that tells
you nothing about whether the popover still looks right. Every phase note in this work
records both, separately, and says which commits are compile-verified *only*.

### 5.2 Split commits along the verifiability line

One target had no capture path at all. Its sweep therefore landed as **two commits**:

- One provably neutral: every substitution replaced a literal with a token whose value
  equals that literal.
- One that genuinely changes pixels, with its evidence being colour measurements rather than
  screenshots.

The second is revertable without losing the first. **When part of a change is provably safe
and part isn't, don't ship them together** — you have thrown away the ability to revert
cheaply, and you've made the reviewer treat the safe half with the same suspicion as the
risky half.

That split is also the seam a future snapshot harness attaches to, which is worth stating in
the commit message.

### 5.3 The value-multiset proof

For "this refactor cannot change anything" claims, don't assert it — compute it:

> Extract every literal removed by the diff and every token added. Resolve each token
> against its definition. Compare the multisets.

25 values, identical, in the case above. This is a five-minute script and it converts a
reviewer's "looks fine to me" into a proof. It works for spacing, radii, durations, colours
— anything where a refactor claims to be a pure renaming.

### 5.4 Resolve-and-diff for CSS

The website consolidation had no build step and no tests. "Verified by opening it in a
browser and confirming nothing moved" is the weakest possible check and it is what the plan
originally called for.

What was done instead: **parse every rule on both pages before and after, resolve every
`var()` transitively, and compare declaration by declaration.** 38 rules on one page, 13 on
the other, zero differences. Later, when a radius ladder replaced ten raw literals, the same
technique gave: nine sites byte-identical, one intended change.

This is *stronger* than opening the page, not a substitute for it. A browser shows you one
viewport of one page in one state. The resolution diff covers every declaration.

### 5.5 Predict the offset, then check the diff matches the prediction

The sharpest technique in the whole exercise, and the one most worth copying.

Naive pixel diffing tells you *that* pixels changed, which for a deliberate change is
useless. Instead: **before capturing, state what the change should do in numbers, then
verify the diff matches that statement.**

Real example. A spacing token changed one value from 14 to 12. The prediction: the header
card's four children move up by exactly 0, 2, 4 and 6 points respectively (the accumulated
delta), the wordmark row is byte-identical, and everything below the card shifts by a uniform
6pt.

The diff matched, including a max channel delta of 23 in the shifted region — which is not a
re-layout, it is a fixed background gradient seen through translucent cards at a 6pt offset.
That is a *confirmation*, not an observation.

Contrast with what naive diffing gets you: "the bottom 60% of the screen changed." True and
worthless.

### 5.6 Know your capture's noise floor before you trust a capture

Two consecutive captures of the same screen, taken minutes apart, differed in exactly three
bands: the status-bar clock and two live countdowns. **Everything else is pixel-stable.**

Measuring that first is what makes every later diff readable — you know which changed bands
are signal. Without it, every diff has three unexplained regions and you learn to ignore
diffs, which is how visual verification dies.

### 5.7 Assume the capture harness is lying to you

Hard-won, and it generalises to any screenshot tooling:

- **The install pass is never the usable pass** — installing rewrote the home screen layout,
  so the run that installed produced a bad capture roughly half the time.
- **A screen with the widget missing entirely exits 0 with a valid PNG.** Exit code and file
  existence prove nothing. Every capture has to actually be looked at.
- **A build flag can silently disable the thing you're testing.** Building with code signing
  off strips the entitlement that creates the shared container, so the fixture could never be
  seeded and the tool failed 40 lines later with an unrelated-looking error.

### 5.8 Some verification is arithmetic, and it is the cheapest kind

Two checks in this work were neither builds nor screenshots:

- **Contrast ratios**, computed exactly from the WCAG sRGB formula rather than estimated.
- **Compositing a system colour** — resolving a semi-transparent system label over the actual
  background to get the real rendered hex.

Both took minutes and both changed decisions. See §6.

---

## 6. Resolving divergences: measure, don't arbitrate

Three times, two bindings of the same design token held different values. Each time the
instinct is to ask *which one is authoritative* — the Swift, the CSS, the spec document, the
older one. That question has no good answer and produces political rather than technical
outcomes.

**Every time, the productive move was to convert it into a measurement.**

### 6.1 Reframe the question until it has a number in it

Two text-colour roles had one value in Swift and a different value in CSS. The task file
framed it as "picking either set moves pixels, and that is a design decision" — i.e. someone
has to have taste about it.

Reframed: *which pair is more legible on the background both are actually drawn on?* Now it
is arithmetic. The CSS pair was darker on both roles — supporting copy 5.32:1 → 6.66:1, quiet
copy 3.31:1 → 4.05:1. Swift adopted the CSS values. **Nothing got lighter, so no call site
lost legibility**, which is what made it a safe unilateral change across 28 sites.

### 6.2 Map by value, not by name

The plan said to map the platform's system `.secondary` label colour onto the palette's
`textSecondary`. Obvious, and wrong.

Resolving it: the system's secondary label in the light appearance is black at 49.8% alpha,
which over this app's off-white background renders as a hex **three units from the palette's
*tertiary*** and thirty-three from its secondary. The platform has four label levels where
this product has three, so its `.secondary` lands on this palette's *tertiary*.

Mapping by name would have visibly darkened seven labels on the one surface with no
screenshot path. **When you replace a platform semantic colour with your own, composite it
against your actual background and compare hexes.** Names across two vocabularies are false
friends.

### 6.3 Compare elements, not numbers

The open question was whether a web card radius (16px) and the app's per-density card radii
(24/18/14) were meant to be the same thing. Framed as numbers, it is unanswerable.

Framed as elements, it took one line: the app's smallest radius token and the web's accent
bar rule **round the same element** — a 3px-wide vertical rule with one rounded end. Same
element, two answers (2 vs 3), and they disagreed only because nobody had ever put them side
by side. Meanwhile the next two rungs already agreed independently, and the card radii are
per-surface on *both* bindings — two ladders of three, neither derived from the other — so
there was nothing to reconcile there and never will be.

**Generalises to: when two bindings disagree, find an element both actually draw.** The
numbers alone can't tell you whether you're looking at one concept with two values or two
concepts that happen to be adjacent.

### 6.4 Don't resolve a two-value divergence by inventing a third value

The measurement above left one role short of the 4.5:1 that normal-size text wants. A
darker shade holding the same hue clears it at 4.55:1.

That value was **recorded in the spec and not adopted**, with the reason written down:

> Resolving a two-value divergence by inventing a third value neither binding has ever drawn
> is how you get a fourth.

The number is in the spec so the next person doesn't have to recompute it. Adopting it was a
separate decision with a separate justification, and it didn't have one.

### 6.5 A measurement can reframe a decision rather than settling it

The most instructive one. A semantic green was suspected of failing contrast for body text.
It does — 3.31:1 against the app's background, versus the 4.5:1 bar.

But computing the *comparison* numbers reframed the whole question: **almost nothing in this
palette clears 4.5:1 on that background.** The brand red is 3.93. The blue is 3.89. The grey
being replaced is 2.75.

So per surface, adopting green for finished-state text: one surface *improves*, one is
unchanged, and only the third regresses (from near-black text). The decision that followed
was neither of the two originally on the table — it was **green carries the accent bar, the
badge and the tint (all of which clear the 3:1 UI bar), and text stays on the primary role
everywhere.** No new palette entry, no regression, and the accessibility exposure that
already existed got smaller.

**A measurement's job is often to change what the options are, not to pick between the
options you had.**

---

## 7. Where the reasoning lives

A recurring theme, and the thing that most distinguishes this from a tidy-up.

**Every non-obvious value carries its justification in the source, at the definition.** Not
in a wiki, not in a PR comment, not in a task file that gets deleted (this one did). The
token definitions carry doc comments explaining the value. Examples of what that looks like
in practice:

- A colour constant that is *also* transcribed into three asset-catalog JSON files says so,
  and says that nothing will fail to compile if they drift. **Cross-format duplication that
  no compiler checks must be documented at both ends or it will drift silently.**
- A value adopted from another binding records the date, the reason (contrast), the before
  and after ratios, and the invariant it preserved ("nothing in this file gets lighter").
- Two constants that sat 270 lines apart with nothing saying they were related — an
  animation duration and the hold time before it reverts — became adjacent named tokens.
  That relationship was previously nowhere.
- A capability that was **declined** got a longer note than most that were built (see §8).

**The commit message carries what the diff cannot.** These commits routinely run to 20+
lines: what differed for a reason and stays; what differed for no reason and collapsed; the
visible changes, all intended, enumerated; and the verification evidence with its limits.
A commit that says "converge session rows" and shows a 400-line diff is unreviewable. One
that says "the corner radius was 8 on two surfaces and 10 on the third for the same element;
8 wins on majority; the 10 token had no other site and is deleted" can be checked in
isolation.

**The spec document is written last and describes both bindings.** Every token, its Swift
value and its CSS value, plus an explicit list of the tokens that are Swift-only (platform
symbol names, widget density families) — *marked as such rather than silently absent*, so a
reader can tell "not applicable to the web" from "somebody forgot".

**Anti-pattern: the task file as the memory.** This report exists because that file was
about to be deleted. Anything in it that mattered had to already be in the source, the
commits, or the guides. A design decision whose only record is a planning document has a
half-life of about one quarter.

---

## 8. Deciding *not* to build something is a decision, and needs the same rigour

One of the three items left open was a `--app` flag for the screenshot tool, to make
capturing the app itself reliable. It was **declined**, and the reasoning was written into
the tool's docstring:

- Making it reliable requires suppressing a network fetch on launch, and **nothing outside
  the app can do that.**
- It would therefore need a test-only branch in product code. A grep established that
  product code currently reads **no launch arguments anywhere** — so this would be a brand
  new pattern whose only consumer is a screenshot script.
- Against that: the listing screenshots don't need it, and the manual three-command path
  already covers the before/after diffing it was wanted for.
- And: **a flag whose job is "do not refresh" is a bad thing to have one typo away from
  shipping.**

The manual procedure went into the docstring instead of the argument parser — **including
the part that was luck.** The first time it worked, it worked because the fetch happened to
fail, and a failed fetch leaves the seeded fixture intact (the error path writes nothing)
while a successful one replaces it. Out of season that race is usually won, *which is exactly
what makes it unfit to be a supported flag.*

Two things generalise:

1. **Write down the revisit condition and the shape it should take.** "Revisit if app
   screenshots ever go on the listing, and build it as a product capability — an offline
   mode — rather than as test scaffolding." That is useful to the next person; "we decided
   not to" is not.
2. **Document the luck.** A procedure that works for a reason you didn't intend is a trap
   for whoever runs it next. Say which part is load-bearing and which part is a coin flip.

---

## 9. Anti-pattern catalogue

Collected, in rough order of how much damage each does.

| Anti-pattern | Why it bites |
| --- | --- |
| **A `Theme` half the code uses** | Two idioms is worse than one bad idiom. Sweep target-by-target to completion, with counts. |
| **Converging things that look alike** | If only the values differ, converge. If the structure differs, you're building a switch with N bodies. Converge the shared sub-part instead. |
| **A migration period** | "Old and new coexist for now" permanently doubles surface area and guarantees new call sites on the old one. Each convergence commit deletes what it replaces. |
| **Booleans as surface/density axes** | `false` and "not specified" are indistinguishable at the call site, which is where drift hides. |
| **Coarse axes forcing optionality** | If a parameter is optional only because the axis can't tell two cases apart, fix the axis. |
| **Sweeping before converging** | You edit the same call sites twice, and the second edit deletes the first. |
| **Hidden fallbacks (`?? somethingElse`)** | Two of them here drew a place name where a date belonged. Usually a symptom of a component that can't express absence. |
| **Naming-based mapping between two colour vocabularies** | Platform semantic colours are alpha over your background. Composite and compare hexes, or you will move pixels on the surface you can't screenshot. |
| **Inventing a third value to settle a two-value split** | Record it in the spec; adopt it only with its own justification. |
| **Eyeballing "nothing moved"** | One viewport, one page, one state. Resolve and diff instead. |
| **Trusting exit codes from capture tooling** | A screenshot of the wrong thing exits 0 and produces a valid PNG. |
| **Diffing without a prediction** | "The bottom 60% changed" is true and worthless. State the expected offset first. |
| **Reasoning that lives in the task file** | The task file gets deleted. The source doesn't. |
| **Specs written before the code** | A spec written first is a wish list. Written last, every line has a call site. |
| **Dead token accumulation** | Nothing fails to compile when a token loses its last call site. Delete it in the commit that orphans it. |
| **Skipping the arithmetic checks** | Contrast ratios and colour compositing take minutes and changed three decisions here. |

---

## 10. What I'd tell someone starting tomorrow

1. **Write the falsifiable test sentence first.** Six things, one edit each, every surface
   follows. Score it honestly at the start and at the end.
2. **Count before you plan.** The counts are the plan, the acceptance criteria, and the
   argument for doing the work at all.
3. **Look at your web presence, your marketing site, your docs.** In this case it was better
   factored than the app and supplied the vocabulary. It is at minimum another copy of your
   palette, and it is drifting.
4. **Decide runtime-vs-rebuild-time explicitly, on day one.** It removes or adds an enormous
   amount of machinery and it is the one decision that is a rewrite rather than an extension
   if you get it wrong.
5. **Name roles now, one value each. Don't build variant machinery.**
6. **Land the additive phases early** so the token file becomes the place open questions get
   recorded while they're still being argued.
7. **Read every implementation before writing the shared one.** Expect the inventory to be
   wrong about at least one of them, in both directions.
8. **Establish your capture noise floor**, then diff against predictions, not against
   expectations.
9. **Split commits along the verifiability line.** Provably-neutral and visible changes ship
   separately, always.
10. **When two bindings disagree, find the number.** Contrast, resolved hex, the element both
    actually draw. Seniority is not a technical argument.
11. **Put the reasoning where the value is**, and assume every planning document you write
    will be deleted. This one was.
