---
description: Product-invariant rules for preserving No Spoilers' architectural spoiler guarantee.
paths:
  - "NoSpoilersCore/**/*.swift"
  - "NoSpoilers/**/*.swift"
  - "NoSpoilersCore/**/*.json"
  - "NoSpoilers/**/*.json"
  - "scripts/**/*.py"
  - "docs/**/*.html"
  - "listing/**/*.txt"
  - "README.md"
---

# Spoiler Safety Rules

- The product is safe because its data model and storage do not contain results. Never add result, position, points, standings, driver-performance, race-outcome, news, recap, or result-derived fields.
- Treat every new external input as unsafe until its exact schema and rendered output are inspected. Schedule-only data is the only permitted product data.
- Do not add source URLs, API parameters, logs, fixtures, screenshots, test names, comments, or UI copy that can reveal an outcome.
- A session may expose only schedule identity, location, kind, and timing data required by the established domain model. If a requested feature needs more, stop and ask for a product decision.
- Preserve the package/app boundary: shared schedule domain logic belongs in `NoSpoilersCore`; target-specific lifecycle and presentation remain in their owning target.
- Use `spoiler-safety-reviewer` for a read-only audit when changing data ingestion, decoding, models, persistence, app-group data, rendered copy, fixtures, or screenshots.
