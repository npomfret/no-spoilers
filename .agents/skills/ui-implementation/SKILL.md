---
name: ui-implementation
description: Any visible user interface, web or native (React, SwiftUI, UIKit, AppKit). Use when building or changing screens, components, controls, forms, dialogs, copy, labels, headings, icons, tooltips, spacing, colours or accessibility, including small tweaks to a shared control or its text. Covers interface wording, shared design system and thin UI layers. Not for UI tests or server and API work.
---

# UI implementation

Web projects also use `web-factoring`; Apple projects follow the project's Apple HIG skill.

Keep web and native interfaces concise. Every visible word must help the person understand their task, make a decision or act.

Design the default interface for an expert who knows the task and familiar controls. Keep optional explanations available on demand through tooltips and information popovers.

- Never add a heading or subheading unless the user explicitly instructs you to add it. A component's heading slot, an existing screen's headings or an agent's preference for explaining a layout does not supply that instruction. Use layout, grouping and familiar controls to organise the interface.
- Use a recognisable icon with an explanatory tooltip whenever an icon can communicate the action. Use button text only when a suitable icon cannot communicate it adequately. Give every icon control an accessible name and make its tooltip available on keyboard focus as well as hover. Where localization applies, localise accessible names and tooltip text through the project catalogue (see the localization skill).
- Use nicely formatted hover/focus tooltips for concise explanations of an element or action. Tooltips remain non-interactive.
- Where a fuller explanation is useful, provide a small info icon that opens a popover when activated by click, tap or keyboard. Keep that explanatory content inside the optional popover. Give the control an accessible name and support appropriate focus and dismissal behaviour.
- Describe the person's task and the outcome they need to understand. Explanations of internal services, requests, validation pipelines, caching, engines and implementation steps are forbidden unless explicitly requested or essential to a user decision. Keep debug counts, IDs, timings and implementation status out of shipped interfaces unless requested.
- Keep action labels concise and familiar. For example, a necessary text action can say “Submit”. Do not expand it into a description of sending a form to a server and running internal validation. This illustrates the wording rule wherever an action is represented.
- Preserve accessible names, field/group labels, icon tooltips and platform help text. Include necessary errors, recovery steps, useful empty states and consequences of destructive actions without waiting for a separate request.
- For other helper text, ask whether removing it would leave the person stuck or lose a needed fact. Say each thing once, in the user's vocabulary.
- Apply these rules to SwiftUI headers, footers and captions as well as web copy. Existing unnecessary text is not a pattern to copy; removing it is separate work unless requested.

Review changed screens for unrequested headings, actions that could use suitable icons, redundant explanations and exposed implementation details before completing UI work.
### Keep the UI layer thin

For software with a UI, separate rendering and platform interaction from application behaviour. Keep the UI layer focused on layout, binding model state to the screen and forwarding user actions to application-owned operations. This applies across web and native UI frameworks.

- Put business rules, validation decisions, calculations, workflow and state transitions in UI-independent models or collaborators. Make them directly constructible with injected capabilities and testable entirely in memory.
- Let the UI react to changes in that model and translate input into meaningful operations. Keep DOM access, UI elements, platform events and rendering details at the UI boundary. Behaviour code must be callable without mounting components or launching a browser, simulator or desktop application.
- When adding behaviour to a view or component, identify which decisions can move behind that boundary. Give those decisions a cohesive owner and keep framework-specific glue small.
- Cover as much meaningful behaviour as possible with fast, reliable unit tests of those models and collaborators. Keep UI-driven tests focused on the rendering, binding and interaction contracts that require the real UI boundary. Avoid duplicating extensive behavioural coverage through expensive UI scenarios.
- Account for the cost of browser, simulator and desktop automation, including tests that take over the developer's screen. Design the boundary so ordinary behavioural tests can run without those resources.
### Shared UI design system

Apply these rules to every UI platform, including web, macOS, iOS and Android. Every app-wide visual decision, primitive and reusable composed component must have a central, discoverable owner.

- Keep app-wide colours, typography, spacing, dimensions, corners, borders, surfaces, elevation, icons, motion and state treatments in a shared design-token layer. Name tokens for semantic roles and use them consistently across applicable surfaces.
- Build shared primitives from those tokens, then build reusable composed components from the primitives. Centralise complex components as deliberately as simple controls. Feature screens compose the shared system.
- Assume every new on-screen element or composition will be reused. Factor meaningful UI pieces into named, discoverable reusable components from first use, including pieces that currently have only one caller. Keep them independently accessible to other features. Do not hide reusable structure inside another component or wait for a second use before extracting it. A component remaining single-use is an acceptable cost of this policy.
- Give shared components ownership of appearance, interaction, accessibility and supported states. Expose meaningful semantic variants. Feature code supplies domain content and layout choices permitted by the component contract.
- Make the system easy to find through cohesive modules, stable names and a maintained entry point or catalogue identifying tokens, primitives and composed components. Keep it current as shared components change.
- Before creating or changing UI, inspect that entry point and search existing components by purpose, appearance and behaviour. Reuse or extend the canonical owner. Do not recreate its appearance locally or copy an implementation into another feature.
- Route shared decisions through their owners. Feature-local values and overrides must not bypass component appearance or state policy. Put genuinely local geometry at the boundary that owns it.
- When introducing a shared replacement, migrate all applicable callers and remove superseded implementations in the same change. Include loading, empty, error, disabled, preview and alternate-layout paths where applicable.
- Verify the system's propagation claim. Changing an app-wide token or shared component must reach every applicable consumer. Inventory callers and justified exceptions, and inspect representative rendered states that exercise distinct rules. Report any unverified surfaces explicitly.
- Keep platform implementations faithful to the same product meaning while respecting platform interaction and accessibility requirements. When one product spans platforms, keep corresponding design decisions aligned and make required platform differences explicit.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*
