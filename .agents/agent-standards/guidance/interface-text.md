## Interface text

Keep web and native interfaces concise. Every visible word must help the person understand their task, make a decision or act.

Design the default interface for an expert who knows the task and familiar controls. Keep optional explanations available on demand through tooltips and information popovers.

- Never add a heading or subheading unless the user explicitly instructs you to add it. A component's heading slot, an existing screen's headings or an agent's preference for explaining a layout does not supply that instruction. Use layout, grouping and familiar controls to organise the interface.
- Use a recognisable icon with an explanatory tooltip whenever an icon can communicate the action. Use button text only when a suitable icon cannot communicate it adequately. Give every icon control an accessible name and make its tooltip available on keyboard focus as well as hover. Localise accessible names and tooltip text.
- Use nicely formatted hover/focus tooltips for concise explanations of an element or action. Tooltips remain non-interactive.
- Where a fuller explanation is useful, provide a small info icon that opens a popover when activated by click, tap or keyboard. Keep that explanatory content inside the optional popover. Give the control an accessible name and support appropriate focus and dismissal behaviour.
- Describe the person's task and the outcome they need to understand. Explanations of internal services, requests, validation pipelines, caching, engines and implementation steps are forbidden unless explicitly requested or essential to a user decision. Keep debug counts, IDs, timings and implementation status out of shipped interfaces unless requested.
- Keep action labels concise and familiar. For example, a necessary text action can say “Submit”. Do not expand it into a description of sending a form to a server and running internal validation. This illustrates the wording rule wherever an action is represented.
- Preserve accessible names, field/group labels, icon tooltips and platform help text. Include necessary errors, recovery steps, useful empty states and consequences of destructive actions without waiting for a separate request.
- For other helper text, ask whether removing it would leave the person stuck or lose a needed fact. Say each thing once, in the user's vocabulary.
- Apply these rules to SwiftUI headers, footers and captions as well as web copy. Existing unnecessary text is not a pattern to copy; removing it is separate work unless requested.

Review changed screens for unrequested headings, actions that could use suitable icons, redundant explanations and exposed implementation details before completing UI work.
