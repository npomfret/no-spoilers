# Factoring an app onto a design system: the mistakes, and how to catch them

*A failure catalogue from retrofitting a token layer and a shared component boundary onto a
small multi-target Apple app that had no UI tests. The app ships a phone app, a menu-bar
utility, four widget families and a marketing website from one codebase. Yours will differ in
the details; the failure modes won't.*

Most write-ups of this kind of work describe the destination. This one describes the wrong
turns, because those are the transferable part. Every entry below has the same shape:

> **The reasoning that leads there** — which is always plausible, or nobody would do it.
> **The tell** — how you notice, ideally before shipping.
> **The fix** — and where the fix has a cost, what it is.

Several entries are marked ***mine*** — mistakes made and undone during this work, or claims
published and later corrected. They are the ones I'd read first; the avoided mistakes are
cheap to write about, and the committed ones are not.

---

## The catalogue at a glance

| # | Mistake | The tell |
| --- | --- | --- |
| 1 | "Introduce a design system" as the goal | You can't say which parts are done |
| 2 | Planning from reading instead of counting | No number in the plan, and none at the end |
| 3 | Assuming the app is your most advanced binding | You invent a vocabulary the CSS already had |
| 4 | Sweeping call sites before converging components | You edit the same lines twice |
| 5 | A migration period | "Old and new coexist for now" |
| 6 | Writing the spec first | Lines in the spec with no call site |
| 7 | "Behaviour-preserving" claimed, not tested ***mine*** | A refactor commit that quietly changes copy |
| 8 | Environment-injected theme for a rebuild-time reskin | Three roots to inject, each failing silently |
| 9 | "No dark mode yet, so don't name the roles yet" | System colours sitting beside your palette |
| 10 | A boolean where the axis has more than two cases | `false` and unspecified look identical |
| 11 | Optionality papering over a too-coarse axis | View code computing what the theme should answer |
| 12 | N parallel lookups for correlated values | Radius and padding choosable independently |
| 13 | Speculative tokens | Constants with one call site, or none |
| 14 | "Trap where the value doesn't exist" as the whole rule ***mine*** | A runtime hole treated as a design |
| 15 | Dead tokens | Nothing fails to compile when the last site goes |
| 16 | Converging things that merely look alike | The shared body is a switch with N bodies |
| 17 | Trusting your own inventory | The count is wrong in both directions |
| 18 | The component owning its content | It needs the domain model *and* the surface enum |
| 19 | Hidden fallbacks (`?? somethingElse`) | A `??` between two different kinds of thing |
| 20 | Majority as design authority | Accessibility decided by a vote |
| 21 | A representative audit | Skeletons and empty states aren't in the count |
| 22 | "Builds" becoming "verified" | One word for two kinds of confidence |
| 23 | Shipping provable and visible changes together | You can't revert half |
| 24 | Asserting neutrality | "This is a pure rename, trust me" |
| 25 | "I opened it and nothing moved" | One viewport, one page, one state |
| 26 | Diffing without a prediction | "The bottom 60% changed" |
| 27 | Not knowing your capture's noise floor | Three unexplained bands in every diff |
| 28 | Trusting exit codes from capture tooling | A screenshot of nothing exits 0 |
| 29 | Asking which binding is authoritative | Seniority arguments |
| 30 | Mapping platform semantic colours by name | Two vocabularies, one word, different hexes |
| 31 | Comparing numbers instead of elements | Unanswerable "are these meant to be the same?" |
| 32 | Inventing a third value to settle a two-value split | A value nothing has ever drawn |
| 33 | Treating a measurement as a verdict ***mine*** | Only the two original options considered |
| 34 | Triumphant summaries ***mine*** | The uncovered surface quietly drops out |
| 35 | Reasoning that lives only in the task file | The record dies with the plan |
| 36 | Cross-format duplication nobody checks | Two files, one value, no compiler |
| 37 | Not recording what you decided *not* to build | "We looked at that once" |

---

## 1. Scoping

### Mistake 1: "Let's introduce a design system"

**The reasoning.** The codebase is inconsistent, a design system fixes inconsistency, therefore
build one. It sounds like a goal.

**The tell.** At any point in the work you cannot say what fraction is done, so you cannot say
when to stop. The predictable outcome is a `Theme` file that half the code uses — **strictly
worse than no `Theme` file**, because now there are two idioms instead of one bad one.

**The fix.** Replace the goal with a falsifiable sentence. The one used here:

> Change the accent colour, the type scale, the corner radii, the spacing rhythm, the motion,
> and the icon set — one edit each — and have every surface follow.

Three properties make that worth more than any amount of "improve consistency" framing:

1. **It is falsifiable.** At any moment you can say which of the six pass. At the start, one
   did, partly: there was a single palette in code, but the website and the asset catalogs
   were independent copies of it. At the end all six passed.
2. **It scopes by outcome, not by file.** It does not say "clean up the main view controller."
   It says what must become true, which lets the work go wherever it needs to go.
3. **It kills gold-plating.** Anything that doesn't move one of the six is out.

### Mistake 2: Planning from reading instead of counting

**The reasoning.** You've read the code, you know where the mess is, the shape of the work is
obvious. Counting feels like ceremony.

**The tell.** The plan contains no numbers, so neither does the completion report. "Much more
consistent now" is not a claim anyone can check.

**The fix.** One mechanical pass before any design work:

```
88  font call sites, none referring to a shared scale
59  padding call sites, 57 of them numeric literals
69  spacing literals
21  opacity literals
11  absolute point sizes
 0  spacing, radius, typography, motion, or icon constants anywhere in the repo
```

Three things fell out of counting that would not have fallen out of reading:

- **The same intent had four different values.** A "quiet tint" was 0.08, 0.10, 0.12 and 0.15
  depending on which file it was typed in. Nobody decided that; four different days did.
- **Whole categories were invisible.** Nobody lists "we have no motion vocabulary" as a
  problem until they count three inline durations in one file and notice nothing else in the
  product animates at all.
- **One component was rendered by four separate implementations.** Reading finds two of them.

The counts then become the acceptance criteria:

| | was | now |
| --- | --- | --- |
| font calls not from a shared scale | 88 | 35, each a token definition or a documented literal |
| padding numeric literals | 57 | 9 |
| spacing literals | 69 | 2 |
| off-grid strays | 11 | 0 |

**Keep the "documented literal" escape hatch, and make it expensive.** 35 is not 0 and was
never going to be. A literal carrying a comment saying why it isn't a token is fine. A literal
with no comment is a bug. **The count that matters is the second one.**

### Mistake 3: Assuming the app is your most advanced binding

**The reasoning.** The app is where the engineering effort goes. The marketing site is a couple
of static pages someone knocked out.

**The tell.** You find yourself inventing names for concepts — `card`, `border`, `bg` — and
then discover the CSS has had exactly those custom properties for a year.

**The fix.** Inventory the web presence in the same pass as the app. In this case the site was
**better factored than the app**, which reversed the direction of travel: the Swift vocabulary
was taken *from* the CSS rather than invented and back-ported. It is also, at minimum, another
copy of your palette, hand-maintained, already drifting — one of the two pages here was
missing a colour the other had.

---

## 2. Sequencing

### Mistake 4: Sweeping call sites onto tokens before converging components

**The reasoning.** Tokens exist now; start using them. It's the mechanical part, it's safe, it
shows progress.

**The tell.** You edit a line to name its constant, and two weeks later delete the whole file
that line was in.

**The fix.** Order the phases so each one's output is the next one's input:

1. **Add the tokens, unused.** Values transcribed from what's on screen today. Zero risk.
2. **Strings and formatters.** Deduplicate shared copy and formatting rules while the work is
   still covered by unit tests.
3. **Semantic state colours** — the first broad styling change, alone, on its own commit.
4. **Converge the duplicated components**, one per commit, biggest payoff first.
5. **Sweep the call sites onto the tokens**, one target per commit.
6. **The asset-catalog / system level** — things the token layer cannot reach.
7. **The website.**
8. **The spec document**, last.

Two orderings inside that are load-bearing and easy to get wrong:

- **The sweep comes after convergence**, per above.
- **Merging the "which surface am I on" axis is its own phase, before the sweep**, for the
  same reason — the sweep reads that parameter at nearly every site it touches.

### Mistake 5: A migration period

**The reasoning.** Land the new shared component, migrate callers gradually, delete the old one
when everything's moved. Feels lower-risk.

**The tell.** The phrase "for now" in a PR description.

**The fix.** **Each convergence commit deletes what it replaces, in the same commit.** If the
convergence is wrong you revert one commit and you are exactly where you were. If old and new
coexist you have permanently doubled the surface area, and somebody will add a call site to
the old one — not out of carelessness, but because it's still there and it still works.

### Mistake 6: Writing the spec first

**The reasoning.** You can't build to a spec you haven't written.

**The tell.** Lines in the document that no code implements, and no reader can tell which
lines those are.

**The fix.** Plan the target contract early — informally, in the task — and **publish the spec
last, so every line in it has a call site.** Written first, it's a wish list. Written last,
it's a description. The version here documents every token with *both* its bindings (the Swift
value and the CSS value), plus an explicit list of the tokens that are Swift-only — platform
symbol names, widget density families — **marked as such rather than silently absent**, so a
reader can distinguish "not applicable to the web" from "somebody forgot".

### Mistake 7: Claiming "behaviour-preserving" without testing it ***mine***

**The reasoning.** Phase 2 moves duplicated strings and formatters into one place. Nothing
renders differently. It's a pure consolidation.

**The tell.** It wasn't. Three copies of a date-range formatter used two different separators —
one surface said "to" where two said "→". Consolidating them **changed visible copy on one
surface**, and I wrote it up as a phase where "no pixels move."

**The fix.** Two parts. Treat any consolidation of near-duplicates as a **visible change until
proven otherwise**, because near-duplicates differ for a reason or by accident and you don't
know which until you diff them. And pin the chosen behaviour with a test in the same commit —
here, four of them, one of which caught a bad fixture of my own making (a late-evening UTC
timestamp is already the next day in a summer-time timezone).

---

## 3. The token layer

### Mistake 8: An environment-injected theme when the reskin is rebuild-time

**The reasoning.** Themes are contextual, contexts are what the environment is for, inject at
the root and everything downstream reads it. This is the idiomatic answer.

**The tell.** Count your roots. Here there were three: the app's view hierarchy, a menu-bar
item hosted from an app delegate outside any hierarchy, and a widget rendering in a *separate
process* with no host environment to inherit. **An environment-keyed theme has to be
re-injected at every root, and it fails silently at any root someone forgets** — the view just
gets the default and looks approximately right.

**The fix.** Ask the question explicitly on day one: **is the reskin rebuild-time or runtime?**
If rebuild-time, static constants on nested enums. No environment keys, no modifiers, no
injection, no root to forget, and no question about what a widget timeline does with a theme.

**Where it costs.** If a user-selectable theme is ever wanted, this is a rewrite of the
plumbing rather than an extension of it. **Write that revisit condition down in the source.**
It is honest about the cost and it stops the next person re-litigating from scratch.

### Mistake 9: "No dark mode yet, so don't name the roles yet"

**The reasoning.** Semantic colour roles exist to hold variants. No variants, no roles. Adding
them now is speculative generality.

**The tell.** Platform semantic colours (`.primary`, `.secondary`, and friends) sitting beside
your palette at dozens of sites. **They do not move when your palette moves**, which is the
entire problem you're trying to solve — and they're usually the reason someone had to pin the
whole surface to one appearance in the first place.

**The fix.** Name the roles now, **one value each**, mapped to what is on screen today. Adding
a variant later becomes "give each role a second value" rather than "find every colour decision
again."

**The discipline that makes this safe:** do *not* build the variant mechanism. One value per
role. **The naming is the expensive, irreversible part; the variant machinery is cheap and can
wait.** Do the expensive part early in its degenerate form.

### Mistake 10: A boolean where the axis has more than two cases

**The reasoning.** Two sizes, one flag. `compact: Bool`. Obvious.

**The tell — and this is the good one.** `false` and *unspecified* are indistinguishable at a
call site. Here, one screen passed `true` for two badges and passed nothing at all for a third,
so **a single row drew two badge sizes** and had done for months. Nobody could see it, because
the wrong value and the missing value look the same in a diff and in a review.

**The fix.** One named axis with a case per surface. Converting the boolean made the row's
inconsistency a fact you could see. Expect to find more spellings than you planned for: this
codebase had **three** — an enum, a boolean, and the new one — where the plan said two.

**Get the granularity right, too.** The cases here are per *surface*, not per *size class*,
because two widget families shared a card geometry and deliberately did not share a type size.
A three-case density axis physically could not express that.

### Mistake 11: Optionality that papers over a too-coarse axis

**The reasoning.** This component's body text isn't always present, so the parameter is
optional. That's just modelling reality.

**The tell.** **View code computing something the theme should answer.** Under the coarse
three-case axis, one case covered all widget sizes and couldn't distinguish the smallest family
(no room for a body line) from the two with room — so the *call site* worked out the absence and
passed `nil`.

**The fix.** Refine the axis, not the API. With a case per surface, the theme answers it
(`showsBody`) and the parameter becomes required again. **Optionality that exists only because
an enum can't tell two cases apart is a design smell, not a modelling requirement.**

### Mistake 12: N parallel lookups for correlated values

**The reasoning.** Radius, padding, shadow and fill are separate properties, so they get
separate tokens.

**The tell.** Someone changes a card's radius on one surface without its padding, and it looks
wrong in a way nobody can name.

**The fix.** **One function returning the correlated set.** Card geometry here resolves seven
values at once, because a card's radius is not independently choosable from its padding. If two
values must move together, make it impossible to move one.

### Mistake 13: Speculative tokens

**The reasoning.** While we're defining the type scale, define the whole scale. We'll need
`display` and `caption2` eventually.

**The tell.** Constants with one call site, or none.

**The fix.** A stated bar, enforced: **a role is added only once every surface has a real call
site to transcribe.** Not "once we think we'll need it." Two roles qualified in the first pass
here; two more earned their place later, during the sweep, when a fifth call site appeared.

### Mistake 14: Treating "trap where the value doesn't exist" as the whole rule ***mine***

**The reasoning.** Fail loudly. If a canvas has no second line of text, the token lookup for it
should trap rather than invent a size. I wrote this up as the rule.

**The tell.** A trap is a runtime hole presented as a design. It happens to be unreachable here
— that canvas passes no detail — but "unreachable today" is a property of the call sites, not
of the type.

**The fix.** The invariant is **"never invent a default"**, not "always trap". Prefer, in order:

1. make the invalid combination unrepresentable in the component's API;
2. keep the lookup inside the component that knows which cases are valid;
3. use a loud runtime failure only when encoding the subset in the type system costs more
   machinery than the invariant is worth.

Trapping is the third option, and it's a legitimate one — but it is the fallback, not the goal.
What must never happen is returning a plausible invented value, which **silently becomes real
the first time somebody adds the line.**

### Mistake 15: Dead tokens

**The reasoning.** It's a constant. It costs nothing to leave it.

**The tell.** Nothing fails to compile when a token loses its last call site, so nothing tells
you. A token layer accumulates dead entries faster than a codebase accumulates dead functions.

**The fix.** Delete it in the commit that orphans it. One convergence here retired a radius on
the spot: two surfaces used 8, one used 10 for the same element, 8 won, and the 10 token had no
other site — so it went in the same commit rather than becoming a puzzle for later.

---

## 4. Component convergence

### Mistake 16: Converging things that merely look alike

**The reasoning.** Three surfaces draw a header with the same information. That's one component
at three sizes.

**The tell.** The shared implementation's body is `switch surface { case a: … case b: … case c:
… }` with no common structure. You have bought nothing and added a level of indirection.

**The fix.** Read all N implementations *before* writing the one, and test for shared
*structure*, not shared *purpose*. Here, the header turned out to be **four genuinely different
designs**: one surface stacked a name under a wordmark, another put three elements on one line,
the compact widgets drew a single row, the large one stacked. **Only the metadata line actually
repeated, and that is the only thing that converged.** Converge the sub-part that's genuinely
shared and leave the rest alone.

### Mistake 17: Trusting your own inventory

**The reasoning.** You counted. The count said four.

**The tell.** It was five. The fifth was inline in a narrow sidebar column with a genuinely
different layout — and it correctly did not converge either.

**The fix.** Expect the inventory to be wrong in *both* directions: implementations you missed,
and implementations that shouldn't converge. Re-read at convergence time, not at planning time.

### Mistake 18: The component owning its content

**The reasoning.** A session row shows a name, a date and a status. Give it the model.

**The tell.** The component needs the domain model *plus* the surface enum *plus* a formatting
policy, and every new caller adds a case to something.

**The fix.** **The caller owns content; the component owns structure and style.** This is what
let four implementations collapse into one here. The four rows put genuinely different content
on the second line — an absolute date on one surface, a secondary name on another, a relative
time on a third — and different things in the trailing slot, from a live countdown to nothing.
The component takes optional string and view slots. The caller decides what goes in them.

### Mistake 19: Hidden fallbacks

**The reasoning.** The countdown might be absent, and an empty line looks broken, so `??`
something.

**The tell.** **A `??` between two different kinds of thing.** Two here — `countdown ??
location`, and a formatter returning the location when there were no sessions — both drew a
place name where a date or a time belonged. That is not a fallback, it's a category error with
a default in front of it.

**The fix.** Make absence expressible, and the fallbacks evaporate on their own. Once the
converged component took optionals, the honest answer ("there is no second line here") had
somewhere to live and both `??` sites had nothing left to do. **Hidden fallbacks are often a
symptom of a component that couldn't express absence** — fix the expressiveness first and see
what's left.

### Mistake 20: Majority as design authority

**The reasoning.** Two surfaces say 8, one says 10. Democracy.

**The tell.** You catch yourself resolving an accessibility or semantic question by counting.

**The fix.** **For a convergence whose goal is to preserve the existing product, majority is a
useful lowest-churn fallback — it is not authority.** Semantics, accessibility, an existing
specification and platform convention all outrank it. Worked examples from the same phase:

- Corner radius 8 vs 10 for the same element → **8, on majority.** No meaning attached.
- An eyebrow label red on one surface, grey on two → **grey**, but *not* because it was 2-1.
  Red is this product's live-session signal, and the eyebrow marks something that hasn't
  started. **Semantics against the count.**
- Section-label padding 12/4 vs 10/2 → 12/4, plus the discovery that this was **not** platform
  intent at all: the screen is shared, so both rhythms rendered in the same window.

**Write down which rule you used**, because the next reader will otherwise assume you counted.

### Mistake 21: A representative audit instead of a category-complete one

**The reasoning.** You looked at the main view, the detail view and the widget. You found the
duplication. It's thorough enough.

**The tell.** Reading the likely files finds the obvious copies and *feels* thorough. What it
misses is the copies that don't look like the component. The sweep here found **a fifth
implementation of the session row inside a loading skeleton** — hand-built with its own accent
rule, label stack and panel, still carrying the corner radius the convergence had retired two
phases earlier. Skeletons, placeholders, previews and empty states are where duplicate
components hide, because they look like grey rectangles.

**The fix.** Enumerate the categories and count each one — palette and semantic colours,
typography, spacing, radii, opacity, motion, icons, shared components, strings, formatters —
and then, explicitly, **loading skeletons, placeholders, previews and empty states**. For each
candidate convergence, search in three directions before writing anything: upstream callers,
downstream rendering, and lateral copies elsewhere in the repository.

And fix the skeleton the general way: **it draws the real component** with placeholder content,
so it cannot drift from what it stands in for. (Its placeholder strings became non-localised
verbatim text, because they are shapes, not copy.)

---

## 5. Verification without snapshot tests

This is the section worth the most, because it's the situation most teams are actually in. This
repo had unit tests for domain logic and four build wrappers. **None of it covers what this
work changes.** A component convergence that renders the wrong thing compiles and passes
everything.

The honest question — "is a snapshot harness a prerequisite?" — was named as the largest risk
and left open rather than hand-waved. It was ultimately **mitigated enough to proceed, not
eliminated**: two of three surfaces gained pixel evidence, and one never did. Here is the
toolkit that made the work reviewable anyway.

### Mistake 22: Letting "builds" become "verified"

**The reasoning.** All three targets compile and the tests pass. Green.

**The tell.** One word doing two jobs in a status update, usually a session or two after the
work, when whoever writes the summary wasn't there for the caveat.

**The fix.** Keep the two kinds of confidence in separate columns and never merge them.
"All three targets build" is true, useful, and tells you *nothing* about whether the popover
still looks right. Every phase note in this work records build confidence, behaviour confidence
and visual confidence separately, and says which commits are compile-verified **only**.

### Mistake 23: Shipping provable and visible changes in one commit

**The reasoning.** It's one target's sweep. It's one logical change.

**The tell.** A reviewer has to treat the safe 90% with the same suspicion as the risky 10%,
and a revert throws away both.

**The fix.** **Split along the verifiability line.** The one target with no capture path landed
as two commits: one where every substitution replaced a literal with a token of equal value,
and one that genuinely changes pixels and whose evidence is colour measurements rather than
screenshots. The second is revertable without losing the first. That split is also the seam a
future snapshot harness attaches to — worth saying so in the commit message.

### Mistake 24: Asserting neutrality instead of computing it

**The reasoning.** Every change in this commit is a literal replaced by the token holding that
literal. It is neutral by construction.

**The tell.** "Trust me" in a review, and a reviewer who can't practically check 200 lines of
substitutions by hand.

**The fix — the value-multiset proof.** Extract every literal the diff removes and every token
it adds, resolve each token against its definition, and compare the multisets. 25 values,
identical, in the case above. It's a five-minute script and it converts "looks fine to me" into
a proof. Works for spacing, radii, durations, colours — anything where the claim is pure
renaming.

### Mistake 25: "I opened it and nothing moved"

**The reasoning.** It's a website. There's no build step. You look at it.

**The tell.** One viewport, one page, one state, one person's memory of what it looked like
before.

**The fix — resolve and diff.** Parse every rule on every page before and after, resolve every
variable reference transitively, compare declaration by declaration. 38 rules on one page, 13
on the other, zero differences. Later, when a radius ladder replaced ten raw literals, the same
script gave nine sites byte-identical and one intended change. **This is stronger than opening
the page, not a substitute for it.**

### Mistake 26: Diffing without a prediction

**The reasoning.** Capture before, capture after, diff. If pixels changed, look at them.

**The tell.** The diff says "the bottom 60% of the screen changed." True and worthless — and
after two of those, people stop running the diff.

**The fix — and this is the sharpest technique here.** **State what the change should do in
numbers, then verify the diff matches the statement.** A real example: a spacing token moved
from 14 to 12. The prediction, written before capturing: the header card's four children move
up by exactly 0, 2, 4 and 6 points respectively (the accumulated delta), the wordmark row is
byte-identical, and everything below the card shifts by a uniform 6pt.

The diff matched — including a max channel delta of 23 in the shifted region, which is not a
re-layout, it's a fixed background gradient seen through translucent cards at a 6pt offset.
**That is a confirmation, not an observation.**

### Mistake 27: Not knowing your capture's noise floor

**The reasoning.** Two captures of the same screen should be identical.

**The tell.** They aren't, and every diff has a few unexplained regions you learn to ignore —
which is how visual verification quietly dies.

**The fix.** Measure it once, first. Two consecutive captures here differed in exactly three
bands: a status-bar clock and two live countdowns. **Everything else is pixel-stable.** Knowing
that is what makes every later diff readable, because you know which changed bands are signal.

### Mistake 28: Trusting the capture tooling

**The reasoning.** It exited 0 and wrote a PNG.

**The tells**, all three found the hard way:

- **The install pass is never the usable pass.** Installing rewrote the home screen layout, so
  the run that installed produced a bad capture about half the time.
- **A screen with the subject missing entirely exits 0 and writes a valid PNG.** Exit code and
  file existence prove nothing. Every capture has to be looked at by a human.
- **A build flag can silently disable the thing you're testing.** Building with code signing
  off stripped the entitlement that creates the shared container, so the fixture could never be
  seeded — and the tool failed forty lines later with an unrelated-looking error.

**The fix.** Treat the harness as an unreliable narrator, and put each of these in its
docstring the first time it bites you.

### The cheapest verification is arithmetic

Two checks here were neither builds nor screenshots, took minutes each, and **changed three
decisions between them**: contrast ratios computed exactly from the sRGB formula rather than
estimated, and compositing a semi-transparent platform colour over the actual background to get
the real rendered hex. Skipping these is its own mistake; see the next section for what they
found.

---

## 6. Resolving divergences

Three times, two bindings of the same design token held different values.

### Mistake 29: Asking which binding is authoritative

**The reasoning.** One of these is the source of truth. Find out which — the older one, the
spec document, the one in the "real" language.

**The tell.** The discussion contains the words "should be" and no numbers. This question has no
good answer and produces political rather than technical outcomes.

**The fix.** **Convert it into a measurement.** Every time, the productive move was to reframe
until the question had a number in it. Two text-colour roles disagreed across Swift and CSS,
and the plan framed it as "picking either set moves pixels, and that is a design decision" —
i.e. someone has to have taste about it. Reframed: *which pair is more legible on the
background both are actually drawn on?* Now it's arithmetic. The CSS pair was darker on both
roles — supporting copy 5.32:1 → 6.66:1, quiet copy 3.31:1 → 4.05:1 — so Swift adopted it.
**Nothing got lighter, so no call site lost legibility**, which is exactly what made it safe to
change 28 sites at once.

### Mistake 30: Mapping platform semantic colours by name

**The reasoning.** The platform's secondary label maps to your `textSecondary`. It's in the
name.

**The tell.** Two vocabularies sharing a word. Resolving it here: the platform's secondary label
in the light appearance is black at 49.8% alpha, which over this app's off-white background
renders a hex **three units from this palette's *tertiary*** and thirty-three from its
secondary. The platform has four label levels where the product has three, so its "secondary"
lands on the product's tertiary.

**The fix.** Composite against your actual background and compare hexes. Mapping by name would
have visibly darkened seven labels on the one surface with no screenshot path — the worst place
to be wrong.

### Mistake 31: Comparing numbers instead of elements

**The reasoning.** The web card radius is 16; the app's are 24/18/14. Are they meant to be the
same thing?

**The tell.** The question is unanswerable in that form, so it stays open for months.

**The fix.** **Find an element both bindings actually draw.** One line settled it here: the
app's smallest radius token and the web's accent-bar rule round *the same element* — a 3px-wide
vertical rule with one rounded end — and they disagreed 2 against 3 purely because nobody had
put them side by side. Meanwhile the next two rungs already agreed independently, and the card
radii are per-surface on *both* bindings: two ladders of three, neither derived from the other,
nothing to reconcile and never will be. **Numbers alone can't tell you whether you're looking
at one concept with two values or two concepts that happen to be adjacent.**

### Mistake 32: Inventing a third value to settle a two-value split

**The reasoning.** Neither existing value is quite right, and you can compute one that is.

**The tell.** A value that nothing in the product has ever drawn.

**The fix.** The measurement above left one role short of the 4.5:1 that normal-size text wants;
a darker shade holding the same hue clears it at 4.55:1. That value was **recorded in the spec
and not adopted**, with the reason written down: *resolving a two-value divergence by inventing
a third value neither binding has ever drawn is how you get a fourth.* The number is in the spec
so nobody recomputes it. Adopting it would have been a separate decision needing its own
justification, and it didn't have one.

### Mistake 33: Treating a measurement as a verdict between the options you already had ***mine***

**The reasoning.** A semantic green was suspected of failing contrast for body text. Measure it;
if it fails, add a darker companion colour for text. Two options, one measurement, done.

**The tell.** I nearly stopped at the first number. It does fail — 3.31:1 against the app's
background, versus the 4.5:1 bar. That answer would have added a palette entry.

**What the comparison numbers showed instead.** Almost *nothing* in this palette clears 4.5:1
on that background: the brand red is 3.93, the blue 3.89, and the grey being replaced 2.75. So
per surface, adopting green for finished-state text: one surface **improves**, one is unchanged,
and only the third regresses — from near-black text.

**The fix, which was neither original option.** Green carries the accent bar, the badge and the
tint, all of which clear the 3:1 bar for UI components; text stays on the primary role
everywhere. No new palette entry, no regression, and the accessibility exposure that already
existed got smaller. **A measurement's job is often to change what the options are, not to pick
between the options you had.**

### Mistake 34: Triumphant summaries ***mine***

**The reasoning.** The open question was "do we need a snapshot harness first?" We found a way
to capture two surfaces. So the question is answered.

**The tell.** I wrote that the question had been "answered by removing its premise." It hadn't.
One surface never got a capture path at all, and it held the highest-risk part of the sweep.
**The uncovered case quietly dropped out of the summary** — which is the general shape of this
mistake, and it's easiest to commit about your own work.

**The fix.** Say "mitigated, not eliminated", and name what's still uncovered, every time you
restate the status. The residual gap is exactly the thing a later reader needs and the thing a
summary is most likely to lose.

---

## 7. Where the reasoning lives

### Mistake 35: Reasoning that lives only in the task file

**The reasoning.** The task file has all the context. It's detailed, it's current, everyone
working on this reads it.

**The tell.** The task is done, so the file gets deleted — and with it the only record of why
the value is 8.

**The fix, in two halves, because the common overcorrection is worse.** The task file is
**working memory and it's genuinely valuable as that**: it held the inventory, the evolving
plan, phase status, verification limits, changed decisions and open questions across many
sessions, and it's what let the work survive being put down and picked up. Keep it. But
**before deleting it, promote everything durable into the layer that will be loaded when it
matters**:

- token values and their invariants, in doc comments beside the definitions;
- behaviour, in tests;
- the as-built cross-platform contract, in the spec;
- why a specific non-obvious decision was made, in that commit's message.

**A design decision whose *only* record is a planning document has a half-life of about one
quarter.**

What this looks like in practice: two constants that sat 270 lines apart with nothing saying
they were related — an animation duration and the hold time before it reverts — became adjacent
named tokens, and that relationship was previously recorded nowhere at all.

**And the commit message carries what the diff cannot.** A commit saying "converge session rows"
over a 400-line diff is unreviewable. One saying *"the corner radius was 8 on two surfaces and
10 on the third for the same element; 8 wins on majority; the 10 token had no other site and is
deleted"* can be checked in isolation, years later, by someone who wasn't there.

### Mistake 36: Cross-format duplication nobody checks

**The reasoning.** The palette lives in one place in code. Job done.

**The tell.** A brand colour that is *also* transcribed into three asset-catalog JSON files,
because an asset catalog cannot reference code. **Nothing will fail to compile if they drift** —
the app just tints itself with last year's colour.

**The fix.** You usually can't remove this duplication; the platform requires it. So document it
**at both ends**, naming the other end explicitly. A comment that says "this value also exists
in these three files and nothing checks that" is the entire defence available, and it works.

### Mistake 37: Not recording what you decided *not* to build

**The reasoning.** We considered it and said no. Nothing to write down.

**The tell.** Someone proposes it again in six months, with the same enthusiasm and none of the
analysis.

**The fix.** Declining gets the same rigour as building. One capture-tool feature was declined
here, and the note is longer than most of the ones that were built:

- Making it reliable would require suppressing a network fetch on launch, and **nothing outside
  the app can do that.**
- So it needs a test-only branch in product code. A grep established that product code reads
  **no launch arguments anywhere** — a brand-new pattern whose only consumer is a screenshot
  script.
- Against that: the listing screenshots don't need it, and a manual procedure already covers the
  before/after diffing it was wanted for.
- And: **a flag whose job is "do not refresh" is a bad thing to have one typo away from
  shipping.**

Two things generalise. **Write down the revisit condition and the shape it should take** —
"revisit if these screenshots ever go on the store listing, and build it as a product
capability (an offline mode) rather than as test scaffolding" is useful; "we decided not to" is
not. And **document the luck**: the manual procedure worked the first time because a network
fetch happened to fail, and a failed fetch leaves the seeded fixture intact where a successful
one replaces it. A procedure that works for a reason you didn't intend is a trap for whoever
runs it next. Say which part is load-bearing and which part is a coin flip.

---

## What I'd tell someone starting tomorrow

1. **Write the falsifiable test sentence first.** Six things, one edit each, every surface
   follows. Score it honestly at the start and at the end.
2. **Count before you plan.** The counts are the plan, the acceptance criteria, and the argument
   for doing the work at all.
3. **Inventory the website too.** It may be better factored than the app. It is at minimum
   another copy of your palette, and it is drifting.
4. **Decide runtime-vs-rebuild-time explicitly, on day one.** It's the one decision that is a
   rewrite rather than an extension if you get it wrong.
5. **Name the roles now, one value each. Don't build variant machinery.**
6. **Land the additive phase early** so the token file becomes the place open questions get
   written down while they're still being argued.
7. **Read every implementation before writing the shared one**, and expect the inventory to be
   wrong in both directions.
8. **Establish your capture noise floor**, then diff against predictions rather than against
   expectations.
9. **Split commits along the verifiability line.** Provably-neutral and visible changes ship
   separately, always.
10. **When two bindings disagree, find the number** — contrast, resolved hex, the element both
    actually draw. Seniority is not a technical argument.
11. **Keep a ledger while the work is live, and put durable reasoning where the value is.**
    Phase status, changed decisions, evidence and its limits, open questions. Then promote what
    lasts into the source, the tests and the commit messages, because every planning document
    is eventually deleted. This one was.
