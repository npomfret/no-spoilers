# Swift Patterns Guide

Canonical pattern-governance guide for Swift and Apple-platform code in this repo.

## Core rules

- One concern should have one approved implementation pattern.
- Before editing, inspect the nearest existing implementation that solves the same concern.
- Reuse or refactor that pattern instead of creating a second style.
- If no approved pattern exists yet, stop and propose the standard before implementing it broadly.

## Refactoring bias

- Prefer converging existing code onto one shared boundary over adding another layer beside it.
- If two implementations are trying to solve the same problem, the default move is to consolidate them.
- Extract shared behavior when duplication is real; do not cargo-cult abstractions before a shared contract exists.

## Encapsulation

- Keep domain logic out of UI composition when a shared model, service, or state boundary is the established pattern.
- Keep I/O boundaries explicit.
- Prefer small, named types with one responsibility over large mixed-purpose files.
- Do not create one-off `Manager`, `Helper`, `Util`, or `Service` types when an approved boundary already exists for that concern.

## Apple-platform consistency

- Keep macOS and iOS behavior aligned when they share the same product contract.
- Call out intentional platform differences explicitly.
- Do not silently mix architectural styles within the same feature area.

## Naming

- Name types and modules after their real scope today, not a speculative future abstraction.
- Generic names are only acceptable after a real shared contract is established.
