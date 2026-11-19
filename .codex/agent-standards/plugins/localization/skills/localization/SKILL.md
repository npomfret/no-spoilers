---
name: localization
description: Any visible, spoken or accessible text in a web or native app, such as labels, tooltips, toasts, alerts, empty states, permission prompts, notifications, dates, numbers and plurals. Use when adding, rewording or formatting that text, or for translations, languages, locales, i18n, string catalogues, right-to-left layout and text that must fit longer translations. Not for error mapping, serialization, code transforms or developer logs.
---

Applies to every user-facing surface of a project where localization applies, on any
platform, including admin interfaces, native targets such as widgets and extensions,
and player-visible game text (debug-only overlays are not user-facing). Not every
project needs localization. It applies when the project ships several languages, has
a message catalogue in use, or is a public end-user product where translation is
evidenced or plausibly planned. English-only personal, internal or hobby tools with no
catalogue and no multilingual intent are excluded, and each exclusion records its reason in
`project-guidance.json`. A project with no text shown to people (a CLI exporter, a
library) has nothing to localize. An included project that is English-only today is
still subject to the policy: it is what keeps adding a language cheap.

Project-owned translation skills, rules, specialists, catalogues, supported languages,
terminology and tooling take precedence for their project's workflow. This standard
supplies the common policy under them and never replaces them.
### Common policy

- Every user-visible, announced or spoken string comes from the platform's message catalogue. That covers accessible names and hints, tooltips, placeholders, errors, notifications, empty states, widget text and permission-prompt strings.
- Use the project's existing maintained catalogue and formatting mechanism. Do not introduce a second one and do not impose a web library on a native app or the reverse.
- IDs name meaning, not wording or location in the layout. Keep them stable; change the source text of an ID only when the meaning is unchanged, otherwise add a new ID and remove the old one.
- A message is a whole sentence or phrase. Never assemble translated sentences from fragments, concatenation or separately translated labels; word order differs by language. Use named placeholders (positional specifiers only where the platform requires them) and plural/select rules for counts and variants, including languages with more than two plural forms.
- Give translators context: a comment or description for ambiguous, short or placeholder-heavy messages, and keep terminology consistent with the project's existing translations.
- Format numbers, currency, dates, times, durations, lists, units and names with the locale-aware formatter of the platform. Do not hard-code separators, date orders, `en_US`-style locales or 12/24-hour assumptions in user-facing formatting. Fixed locales remain correct for machine formats and tests.
- Allow translated text to grow by at least a third. Avoid fixed text dimensions and truncating the only label. Prefer leading/trailing over left/right and let layouts mirror for right-to-left languages.
- Put no words in images, icons or CSS glyphs. Provide translated alternative text or accessible names where an image carries meaning.
- Preserve user-entered text exactly: do not translate, normalise or re-case it.
- Server text shown to people is either localized by the server for the viewer's locale or sent as a code or catalogue ID that the client renders. The server needs the viewer's locale for the first form. Developer-only text (logs, exceptions never displayed) is not localized.
- Icon controls need localized accessible names and matching tooltips (UI skills own the icon policy).
- Keep source-locale UI-test conventions: tests locate by literal source-locale text and launch with the source locale (iOS: `-AppleLanguages (en) -AppleLocale en_US`). Layout checks for other languages are separate runs, not changes to those tests.
### Translation-maintenance workflow

Derived from wl-bill-splitter (CLI-first, English first, finalize at the end), pwa-instructions (completeness and provenance checks), wake-me-up and super-funmax-music (catalogue sync, source-locale tests, deferred real-translation layout checks). Where the project documents a different step, the project's wins.

1. Establish scope: source language, target languages, and the surfaces affected (app, widget, extension, Info.plist, admin UI, server text). Supported languages come from the project (catalogue contents, `catalog.json`, project docs), never from the agent. If none is stated, ask (decision D1).
2. Find the project's workflow before editing: owned skill, rule, command, specialist, translation CLI, docs, tests. Use it. Ask or stop if it cannot complete the work; do not add bypasses, skip lists or fallback hacks.
3. Update the source language first, with meaning-based IDs and context comments.
4. Find the delta: missing, stale, new and `needs_review` entries per target language using the project's tooling (diff/sync command, String Catalog state, key tests). Do not hand-edit generated or extracted rows when a project editor exists.
5. Translate whole messages with project terminology and context. Keep placeholders, markup and product/brand names exact. No TODO text, copied English or machine placeholders in a target language, except protected names.
6. Validate structure with the project's checks: key parity, placeholders, plural categories required by each locale, empty values, typed-key or compile checks, source-locale UI tests. Structural checks show shape, not linguistic accuracy.
7. Check rendered layout for the changed screens: long text, right-to-left if supported, and the languages actually delivered. A pseudo-locale is a smoke test; it does not replace real translations (super-funmax-music owner decision, 2026-11-02).
8. Review: structural checks do not show linguistic accuracy. Say so in the report, state which languages were translated by the agent and which were reviewed by a person, and flag low-confidence terms. Agent translations of a language nobody reviewed are reported as unreviewed.
9. Report: IDs added, changed and removed; languages and their state; checks run and outcomes; anything unverified.

Do not add application translations as part of managing-repository work.
### Web mechanisms

- Keep the project's library: FormatJS/react-intl (ICU), i18next/react-i18next, or its custom module. Use FormatJS/ICU only when there is none. Do not mix two in one app.
- One translation module; components use its hook or helper, not raw library calls. Prefer typed message IDs so a missing ID fails at build time.
- Catalogue formats in use: ICU strings in `en.json` or TypeScript objects (react-intl), `{{name}}` interpolation with `_one/_other` suffix plurals (i18next). Follow the project's.
- Literal keys only where the project requires static discoverability (wl-bill-splitter). Otherwise map dynamic domains through explicit lookups rather than constructing IDs.
- Set `lang` and `dir` on the document from the active locale. Give locale-formatting calls the active locale, not `undefined` or a hard-coded `en-GB`.
- Enforce no literal copy in components where the project has a lint rule (solstice `LITERAL_COPY`); otherwise review.
- Browser layout checks follow `standards/browser-testing.md` with the source locale for ordinary tests.
### Native mechanisms (Apple platforms)

- Use the project's String Catalogs (`.xcstrings`) and platform APIs: `String(localized:)`, `LocalizedStringResource`, `LocalizedStringKey` in SwiftUI, `bundle:` for package and extension code. Each target that shows text (app, widget, extension, Info.plist via `InfoPlist.xcstrings`) has its own catalogue or an explicit shared one.
- Plurals and device/width variants use catalogue variations, not code branches such as `count == 1 ? ...`. Dynamic messages take arguments and format specifiers, with positional specifiers when order may change.
- User text uses `Text(verbatim:)` or `String(format:)` only for non-translatable data (song titles, identifiers), as project rules allow.
- Dates, numbers and durations use `FormatStyle`; fixed-locale formatters (`en_US_POSIX`) only for machine formats.
- Keep extracted or tool-owned catalogue rows to the project's editor or `xcstringstool` sync; do not hand-edit them where a project rule forbids it.
- Accessibility labels, hints and values go through the same catalogue.
- A native project with String Catalog build settings but no catalogue (no-spoilers) adopts the catalogue before any translation work; that is a project decision.
- Layout checks use `-NSDoubleLocalizedStrings YES` and `-NSForceRightToLeftWritingDirection YES` runs as smoke tests, and real translated runs for delivered languages.
- Do not use web libraries, JSON catalogues or i18next conventions in native code.
### Decisions

Decided by the user (2026-11-19):

- D1: Agents may write translations for the project's supported languages, using project terminology and context, and must list every new or changed translated string in their report for optional human review. Supported languages still come from the project, never from the agent.
- D3: In a project where localization applies and that is English-only today, new and changed UI text goes into a message catalogue. Migrating existing hard-coded text is not required by this standard. Projects where localization does not apply are unaffected.
- D4: No single web library is mandated. Existing projects keep theirs; new projects choose one already used in the fleet (i18next or react-intl).
- D5/D6: Admin and internal interfaces are in scope. Player-visible game HUD text is in scope; debug-only overlays are not.

Open; until decided, no new requirement applies and each project's existing practice stands:

- D2: Whether untranslated or `new` catalogue entries block a build or release.
- D7: Whether server-owned display text migrates to codes or receives the viewer's locale.
- D8: Whether shared structural-check tooling is provided, or only project tooling is recommended.
- D9: Whether App Store listing and metadata localization is in this skill's scope.
- D10: Whether wake-me-up's deferred layout CI leg and super-funmax-music's real-translation layout approach become shared policy.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*
